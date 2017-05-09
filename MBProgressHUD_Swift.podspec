
Pod::Spec.new do |s|
  s.name         = "MBProgressHUD_Swift"
  s.version      = "0.0.1"
  s.summary      = "MBProgressHUD Swift Version."
  s.homepage     = "https://github.com/Minlison/MBProgressHUD_Swift"
  s.license      = { :type => "MIT", :file => "LICENSE" }
  s.author             = { "Minlison" => "yuanhang.1991@icloud.com" }
  s.platform     = :ios, "8.0"
  s.source       = { :git => "https://github.com/Minlison/MBProgressHUD_Swift.git", :tag => "#{s.version}" }
  s.source_files  = "MBProgressHUDSwift/MBProgressHUDSwift/*.swfit"
end
