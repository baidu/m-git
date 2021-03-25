### 快速开始


#### 1、安装MGit工具

环境要求：

- 系统：支持 macOS、Ubuntu，暂时不支持 window-
- Ruby版本: >= 2.3.7

```ruby
$ gem install m-git
```

#### 2、初始化多仓库 

初始化多仓库使用 `mgit init` 命令;

类似于 Git 从远程 clone 新仓库, 会将多个仓库 clone 到本地;

下面通过一个demo体验一下MGit命令：

```ruby
# 2.1 建议在一个新文件夹中拉取demo
$ mgit init -g https://github.com/baidu/m-git.git

# 2.2 体验一下mgit命令
$ mgit -l                 显示所有migt管理的仓库
$ mgit branch --compact   查看多仓库的分支
$ mgit status             产看仓库分支超前/落后情况
```