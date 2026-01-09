#
#  CooOrchestrator.podspec
#  CooOrchestrator
#
#  Created by Coo on 2026/01/09.
#  Copyright © 2026 Coo. All rights reserved.
#
#  文件功能描述: CooOrchestrator的CocoaPods配置文件
#  类型功能描述: 定义库的元数据、依赖、源文件路径及构建配置，用于发布到CocoaPods仓库
#

Pod::Spec.new do |s|
  s.name             = 'Orchestrator'
  s.version          = '0.0.2'
  s.summary          = '一个用于模块化管理应用生命周期与服务分发的编排框架。'

  s.description      = <<-DESC
                       CooOrchestrator是一个用于模块化管理应用生命周期与服务分发的编排框架，
                       提供统一的服务协议、时机与优先级、生命周期与自动注册（Manifest），
                       支持多线程安全调度。
                       DESC

  s.homepage         = 'https://github.com/CircularCyanStone/Orchestrator'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'coocy' => 'coo@example.com' }
  s.source           = { :git => 'https://github.com/CircularCyanStone/Orchestrator.git', :tag => s.version.to_s }

  s.ios.deployment_target = '13.0'
  s.swift_versions = ['5.0']

  s.source_files = 'Sources/Orchestrator/**/*.{h, swift}'
  s.exclude_files = 'Sources/CooOrchestrator/macros/**/*'
  s.public_header_files = 'Sources/Orchestrator/**/CooOrchestrator.h'
  
end
