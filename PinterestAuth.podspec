Pod::Spec.new do |s|
  s.name = "PinterestAuth"
  s.version = `git tag`.split("\n").last
  s.summary = "A framework that wraps the Pinterest API's Oauth2 process for Week 5 of the iOS Training Lab"
  s.homepage = "https://github.com/codebasesaga/PinterestAuth"
  s.author = { "Codebase, SAGA" => "hello@codebasesaga.com" }
  s.license = { :type => 'MIT', :file => 'LICENSE' }
  s.source = { :git => "https://github.com/codebasesaga/PinterestAuth.git", :tag => "#{s.version}" }
  s.source_files = "Sources", "Sources/**/*.{h,m}"
  s.swift_version = '4.0'
  s.ios.deployment_target = '8.0'
end
