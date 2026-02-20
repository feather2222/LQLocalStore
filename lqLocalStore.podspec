Pod::Spec.new do |s|
  s.name         = "lqLocalStore"
  s.version      = "1.0.0"
  s.summary      = "高性能本地缓存/文件存储库，支持多级缓存、批量、标签、优先级、压缩、监控、Mock、分片、自动扩容等特性。"
  s.description  = <<-DESC
lqLocalStore 是一个 Swift 本地缓存/文件存储库，支持多级缓存、批量、标签、优先级、压缩、详细日志、Mock、分片、自动扩容、监控、可插拔策略等高级特性，适用于 iOS/macOS 项目。
  DESC
  s.homepage     = "https://github.com/feather2222/LQLocalStore"
  s.license      = { :type => "MIT", :file => "LICENSE" }
  s.author       = { "xiangduojia" => "1402479908@qq.com" }
  s.source       = { :git => "https://github.com/feather2222/LQLocalStore.git", :tag => s.version }
  s.swift_version = "5.0"
  s.ios.deployment_target = "11.0"
  s.osx.deployment_target = "10.13"
  s.source_files  = "lqLocalStore/**/*.{swift}"
  s.exclude_files = "lqLocalStoreTests"
  s.requires_arc  = true
end
