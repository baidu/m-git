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

### 3、已有仓库如何使用 MGit

- 根据文档[配置 manifest.json](../config/manifest.md)

  将要管理的仓库都配置到 manifest.json 中
  
- 将 manifest.json 放到一个仓库中管理

  这个仓库同样会在 manifest.json 中描述，并且需要配置 "config-repo": true 
  
  这个仓库称为配置仓库，也叫做**主仓库**，其他仓库叫做**子仓库**
     
- 使用 `mgit init -f manifest文件路径`  初始化多仓库，命令测试 manifest.json 配置是否正常

  注意这个命令不会重复拉取主仓库，只会拉取所有的子仓库到当前目录，并在当前目录创建一个.mgit
  
  你可以在当前目录中看到每个仓库的源码，他们的路径可以通过  manifest.json 的 dest字段配置
  
  你也可以在 .mgit/source-git/ 下看到所有仓库的.git, 这是 MGit 对所有仓库的托管
  
- 本地测试成功后，你可以提交主仓库中的 manifest.json，推送主仓库的变更到远端
  
- 通过 `mgit init -g 主仓库地址` 命令初始化多仓库
  





