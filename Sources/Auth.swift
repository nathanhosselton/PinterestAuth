import Foundation

/// The type containing the method and properties for managing a user's
/// authentication with Pinterest via their Oauth2 login process.
public enum Auth {

    /// The client id which was defined for your app at https://developers.pinterest.com/apps/.
    public static var client_id: String?

    /// The client secret which was defined for your app at https://developers.pinterest.com/apps/.
    public static var client_secret: String?

    /// The privileges being requested of the user's Pinterst account.
    /// By default, this property is configured to request all privileges.
    public static var scope = Scope.all

    /// The user's token used to make autenticated requests to Pinterest on behalf of the user.
    /// This property is nil if no user is currently logged in.
    /// - Note: The token is automatically stored to `UserDefaults` and thus will be immediately
    /// available on successive app launches.
    public private(set) static var token: String? {
        get {
            return UserDefaults.standard.string(forKey: "token")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "token")
            UserDefaults.standard.synchronize()
        }
    }

    /**
     A property used to determine if a user is currently logged in.
     Returns `true` if there is currently a logged in user. Otherwise returns `false`.
     Usage:

         if Auth.ed {
            //logged in
         }

    */
    public static var ed: Bool {
        return token != nil
    }

    private static var scheme: String? {
        guard let client = client_id, !client.isEmpty else { return nil }
        
        //Pinterest auto-generates the redirect uri scheme for iOS apps in this format
        //See: https://github.com/pinterest/ios-pdk/issues/60
        return "pdk\(client)"
    }

    private static var redirect_uri: String? {
        guard let scheme = scheme else { return nil }
        return scheme + "://"
    }

    private static var state: String?

    /// The various errors that can occur when authenticating with the Pinterest API.
    public enum Error: LocalizedError, CustomStringConvertible {
        /// Occurs when `Auth.client_id` is nil when attempting to use `Auth.url`.
        case clientIdNotSet
        /// Occurs when `Auth.client_secret` is nil when attempting to use `Auth.url`.
        case clientSecretNotSet
        /// Occurs if the client id or secret are nil upon returing from Pinterest login. This should be rare.
        case contextLost
        /// Occurs if the client id or secret contain unexpected characters.
        case malformedInput
        /// Occurs if the unique value included with the redirect is not returned by Pinterest.
        case unexpectedState
        /// Occurs if the redirect url passed back to the app from Pinterest after login is in an unexpected format.
        case unexpectedRedirect(URL)
        /// Occurs if the request for a token returns data in an unexpected format.
        case unexpectedResponse(HTTPURLResponse?, Data?, Swift.Error?)

        /// The error description.
        /// - Note: Exists purely for conformance to `CustomStringConvertible`, allowing for string interpolation.
        public var description: String {
            let msg: String

            switch self {
            case .clientIdNotSet:
                msg = "A client id has not been set on `Auth.client_id`. You must set a client id before accessing `url`. You can retreive your Pinterest client id from your app page at https://developers.pinterest.com/apps/."
            case .clientSecretNotSet:
                msg = "A client secret has not been set on `Auth.client_secret`. You must set a client secret before accessing `url`. You can retreive your Pinterest client secret from your app page at https://developers.pinterest.com/apps/."
            case .contextLost:
                msg = "The client id and/or secret was lost before the user was directed back to the app. Ideally, you would handle this by asking the user to attempt login again, but don't worry about that for now as this should be very rare."
            case .malformedInput:
                msg = "The `client_id` provided was malformed in a manner that prevented generation of a valid `url`. This is a programmer error. Verify the `client_id` is correct and try again."
            case .unexpectedState:
                msg = "The auth redirect came back with a state that did not match the value sent. This can sometimes indicate that someone was spoofing your app. But probably something just went wrong."
            case .unexpectedRedirect(let url):
                msg = "The Pinterest redirect did not contain the expected information (namely: the \"state\" and \"code\"). Inspecting the url may provide possible resolution information: \(url)"
            case .unexpectedResponse(let resp, let data, let error):
                let debug = error?.localizedDescription ?? "" + (data?.stringified ?? resp?.description ?? "No further information was available")
                msg = "The token request responded in an unexpected format. Inspecting the response may reveal the cause:\n\(debug)"
            }

            return "PinterestAuth Error: " + msg
        }

        /// The error description.
        /// - Note: Exists purely for conformance to `LocalizedError`, allowing use of `localizedDescription`.
        public var errorDescription: String? {
            return description
        }
    }

    /// The available privileges that may be requested of the user's Pinterst account
    public enum Scope: String {
        /// Read a user's public information.
        case readPublic = "read_public"
        /// Write to a user's public information.
        case writePublic = "write_public"
        /// Read a user's relationship information with other users.
        case readRelationships = "read_relationships"
        /// Write to a user's relationship information.
        case writeRelationships = "write_relationships"

        /// Returns a collection of all scopes.
        public static var all: [Auth.Scope] {
            return [.readPublic, .writePublic, .readRelationships, .writeRelationships]
        }
    }

    /// The result of an access token request.
    public enum Result {
        /// The token request completed successfully and is available in `Auth.token`
        case success
        /// The token request failed. Information will be provided in the `error` object.
        case failure(error: Swift.Error)
    }

    /**
    The url where you will send users wishing to login with Pinterest. Usage:

         UIApplication.shared.open(Auth.url)

    - Warning: You **must** set `Auth.client_id` and `Auth.client_secret` _before_ using this property.
    Failure to do so is considered a programmer error and will result in a crash.
     */
    public static var url: URL {
        guard let client = client_id, !client.isEmpty else { fatalError(Error.clientIdNotSet.description) }
        guard let secret = client_secret, !secret.isEmpty else { fatalError(Error.clientSecretNotSet.description) }

        state = UUID().uuidString

        let params = [
            "response_type": "code",
                "client_id": client,
                    "state": state!,
                    "scope": scope.reduce("") { $0 + "," + $1.rawValue },
             "redirect_uri": redirect_uri
        ]

        var url: URL? {
            var cc = URLComponents()
            cc.scheme = "https"
            cc.host = "api.pinterest.com"
            cc.path = "/oauth"
            cc.queryItems = params.map(URLQueryItem.init)

            return cc.url
        }

        guard let uu = url else { fatalError(Error.malformedInput.description) }

        return uu
    }

    /**
     The method used to make the request for the logged in user's token after they have returned from Pinterest.com.
     You call this method from your `AppDelegate`'s `openUrl` method, passing in the url. This method checks the url
     to determine if it was intended for your app, returning `true` or `false` accordingly.

     If the url is the expected redirect from Pinterest login, the request for the user's token is made and the provided
     `completion` is called with the result of the request, when finished. If the request is sucessful, `Auth.token` will become
     available for use in your app for authenticated requests.

     Usage:

         func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any] = [:]) -> Bool {
             return Auth.requestAccessToken(with: url) { result in
                 switch result {
                 case .success:
                     //Token is available
                 case .failure(let error):
                     //Handle the error
                 }
             }
         }

     - Parameters:
        - redirect: The url passed into your `AppDelegate`'s `openUrl` method.
        - completion: The completion handler for the token request.
        - result: The result of the token request passed into the `completion`.
     */
    public static func requestAccessToken(with redirect: URL, completion: @escaping (_ result: Result) -> Void) -> Bool {
        //Verify this redirect is ours. If it's not, return without calling student completion.
        //This check depends on `client_id` being non-nil but that should never happen here.
        guard redirect.scheme == scheme else { return false }

        //Verify the redirect containts the expected parameters else continue redirect but immediately complete with an error.
        guard let cc = URLComponents(url: redirect, resolvingAgainstBaseURL: false),
            let stateItem = cc.queryItems?.first(where: { $0.name == "state" }),
            let codeItem = cc.queryItems?.first(where: { $0.name == "code" }),
            let code = codeItem.value
            else {
                completion(.failure(error: Error.unexpectedRedirect(redirect)))
                return true
            }

        //Verify the state of the redirect matches what was sent else continue the redirect but immediately complete with an error.
        guard stateItem.value == state else {
            completion(.failure(error: Error.unexpectedState))
            return true
        }

        //Verify the client_id and client_secret are still set else continue the redirect but immediately complete with an error.
        //This should be impossible, but if it isn't, this code will never execute currently as the scheme check above will also fail.
        guard let client = client_id, !client.isEmpty, let secret = client_secret, !secret.isEmpty else {
            completion(.failure(error: Error.contextLost))
            return true
        }

        let params = [
                "grant_type": "authorization_code",
                 "client_id": client,
             "client_secret": secret,
                      "code": code
        ]

        var url: URL? {
            var cc = URLComponents()
            cc.scheme = "https"
            cc.host = "api.pinterest.com"
            cc.path = "/v1/oauth/token"
            cc.queryItems = params.map(URLQueryItem.init)

            return cc.url
        }

        //Verify the generated auth url is valid else continue the redirect but immediately complete with an error.
        guard let authUrl = url else {
            completion(.failure(error: Error.unexpectedRedirect(redirect)))
            return true
        }

        var request: URLRequest {
            var rr = URLRequest(url: authUrl)
            rr.httpMethod = "POST"
            rr.setValue("PinterestAuth (com.codebasesaga.framework.PinterestAuth)", forHTTPHeaderField: "User-Agent")
            return rr
        }

        //Ask Pinterest for the token
        URLSession.shared.dataTask(with: request) { (data, resp, error) in
            switch (data, resp as? HTTPURLResponse, error) {
            case (let .some(data), let resp, _):
                if let json = (try? JSONSerialization.jsonObject(with: data, options: .allowFragments)) as? [String: Any],
                    let token = json["access_token"] as? String {
                    self.token = token
                    completion(.success)
                } else {
                    completion(.failure(error: Error.unexpectedResponse(resp, data, nil)))
                }
            case (_, let resp, let .some(error)):
                completion(.failure(error: Error.unexpectedResponse(resp, nil, error)))
            case (_, let resp, _):
                completion(.failure(error: Error.unexpectedResponse(resp, nil, nil)))
            }
        }
        .resume()

        return true
    }
}



private extension Data {
    ///Attempts to decode the data using `JSONSerialization`, falling back to UTF-8 `String` decoding.
    var stringified: String? {
        let json = try? JSONSerialization.jsonObject(with: self, options: .allowFragments)
        return json != nil ? Optional.some(String(describing: json)) : String(data: self, encoding: .utf8)
    }
}
