#
# Be sure to run `pod lib lint SJM3u8MediaCache.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'SJM3u8MediaCache'
  s.version          = '0.2.2'
  s.summary          = 'm3u8 web video cache download'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
TODO: Add long description of the pod here.
                       DESC

  s.homepage         = 'https://github.com/CrazyDrop/SJM3u8MediaCache'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'erik' => 'wo160.160@163.com' }
  s.source           = { :git => 'https://github.com/CrazyDrop/SJM3u8MediaCache.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '8.0'

  s.source_files = 'SJM3u8MediaCache/Classes/**/*'
  
  # s.resource_bundles = {
  #   'SJM3u8MediaCache' => ['SJM3u8MediaCache/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
#   s.dependency 'AFNetworking', '~> 3.2.1'
#   s.dependency 'M3U8Kit', '~> 0.3.2'
   s.dependency 'AFNetworking', '= 3.2.1'
   s.dependency 'M3U8Kit', '= 0.3.2'

end
