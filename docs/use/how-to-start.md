## 快速开始


### 1、安装 MGit 工具

环境要求：

- 系统：支持 macOS、Ubuntu，暂时不支持 window-
- Ruby版本: >= 2.3.7

```ruby
$ gem install m-git
```

### 2、初始化多仓库Demo

初始化多仓库使用 `mgit init` 命令;

类似于 Git 从远程 clone 新仓库, 会将多个仓库 clone 到本地;

下面通过一个demo体验一下MGit命令：

```ruby
# 2.1 建议在一个新文件夹中拉取demo
$ mgit init -g https://github.com/baidu/m-git.git

# 2.2 体验一下mgit命令
$ mgit -l                 显示所有mgit管理的仓库
$ mgit branch --compact   查看多仓库的分支
$ mgit status             产看仓库分支超前/落后情况
```

### 3、已有多仓库如何迁移到 MGit 管理

- 根据文档[配置 manifest.json](../config/manifest.md)

  将要管理的仓库都配置到 manifest.json 中
  
- 将 manifest.json 放到一个仓库中管理

  这个仓库同样会在 manifest.json 中描述，并且需要配置 "config-repo": true 
  
  这个仓库称为配置仓库，也叫做**主仓库**，其他仓库叫做**子仓库**
     
- 使用 `mgit init -f manifest文件路径`  命令初始化多仓库，测试 manifest.json 配置是否正常

  注意这个命令不会重复拉取主仓库，只会拉取所有的子仓库到当前目录，并在当前目录创建一个.mgit
  
  你可以在当前目录中看到每个仓库的源码，他们的路径可以通过  manifest.json 的 dest字段配置
  
  你也可以在 .mgit/source-git/ 下看到所有仓库的.git, 这是 MGit 对所有仓库的托管
  
- 本地测试成功后，你可以提交主仓库中的 manifest.json，推送主仓库的变更到远端
  
- 通过 `mgit init -g 主仓库地址` 命令初始化多仓库
  

     
### 4、使用 MGit 管理多仓库的案例
  
  推荐使用**同名分支原则**管理多仓库: 子仓库的分支与主仓库保持一致（子仓库单独锁定分支的情况除外）
   
  推荐通过在主仓库中[配置 local_manifest.json](../config/manifest.md#3--local_manifest)， 控制要同时操作哪些仓库

  例如： 一个工程中有 a、b、c、d 、e、f、g等多个仓库, 当一个需求 A 涉及到三个仓库 a 、b、 c时
  
  - 从 master 新建开发分支 feature_A
    - 拉取主仓库到开发分支 feature_A `git checkout -b feature_A`(操作单仓库时可以直接使用git命令)
    - [创建 local_manifest.json](../config/manifest.md#3--local_manifest) 在 local_manifest.json 中配置 MGit 只管理主仓库和子仓库 a 、b、 c 
      ```ruby
          {
            "mgit-excluded": true,
            "repositories": {
              "config_repo": {
                "mgit-excluded": false
              },
              "a": {
                "mgit-excluded": false
               },
              "b": {
                "mgit-excluded": false
               },
              "c": {
                "mgit-excluded": false
               }
            }
          }
      ```
    - push 主仓库的变更到远程 （包含 local_manifest.json配置的变更）
    - 拉取子仓库 a 、b、 c 的开发分支 feature_A  `mgit checkout -b feature_A`
    - 使用 `mgit branch --compact` 命令查看分支状态
    
  - 在 feature_A 分支开发需求
    - `mgit status`  查看多仓库状态
    - `mgit add .`   添加到暂存区
    - `mgit commit -m 'xxx'` 提交多仓库的变更
    - `mgit push`    推送多仓库到远程
    
  - 合并 feature_A 到 master 分支
    - `mgit merge feature_A -m "xxx comment..."` 将代码 merge 回主干分支
    - 删除主仓库中的 local_manifest.json 文件（如果有增、删、改仓库配置的情况，需要更新到 manifest.json）
    
  
