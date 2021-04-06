# MGit

MGit 是一款 Ruby 封装的基于 Git 的多仓库管理工具，可以高效的、同时的对多个 Git 仓库执行 Git 命令。
适合于在多个仓库中进行关联开发的项目，提高 Git 操作的效率，避免逐个执行 Git 命令带来的误操作风险。

- **易用的命令**
封装 Git 命令，命令和参数均由 Git 衍生而来，会使用 Git 就可以成本低上手 MGit。

- **直观高效的执行命令**
提供图表化的结果展示，开发者可以快速查看命令在多个仓库的执行结果；
多线程并发执行多仓库命令，通过仓库缓存机制提高仓库的拉取效率；

- **安全的执行命令**
在执行命令前对多仓库状态进行安全检查：分支是否异常，工作区是否未提交代码等；
对 .git 进行托管与 Git 工作区分类，避免误删丢失改动或提交；
执行存在风险的操作时，会给与风险操作提示，避免误操作；

- **方便扩展**
支持加载 ruby-gem 包作为插件，gem 包名格式 `m-git-${suffix}`和`mgit-${suffix}`
快速的扩展 MGit 的命令，增加自定义命令，扩展已有命令的功能；
提供类似`git hook`的 hook 点，方便开发者实现自定义逻辑；

## 快速开始
  #### 1、安装 MGit 工具

环境要求：

- 系统：支持 macOS、Ubuntu，暂时不支持 Windows
- Ruby版本: >= 2.3.7

```ruby
$ gem install m-git
```

#### 2、初始化多仓库 

初始化多仓库使用 `mgit init` 命令;

类似于 Git 从远程 clone 新仓库, 会将多个仓库 clone 到本地;

下面通过一个 demo 体验一下 MGit 命令：

```ruby
# 2.1 建议在一个新文件夹中拉取demo
$ mgit init -g https://github.com/baidu/m-git.git

# 2.2 体验一下mgit命令
$ mgit -l                 显示所有mgit管理的仓库
$ mgit branch --compact   查看多仓库的分支
$ mgit status             产看仓库分支超前/落后情况
```


#### 3、已有仓库如何使用 MGit

- 根据文档[配置 manifest.json](docs/config/manifest.md)

  将要管理的仓库都配置到 manifest.json 中
  
- 将 manifest.json 放到一个仓库中管理

  这个仓库同样会在 manifest.json 中描述，并且需要配置 "config-repo": true 
  
  这个仓库称为配置仓库，也叫做**主仓库**，其他仓库叫做**子仓库**
     
- 使用 `mgit init -f manifest文件路径` 初始化多仓库，命令测试 manifest.json 配置是否正常

  注意这个命令不会重复拉取主仓库，只会拉取所有的子仓库到当前目录，并在当前目录创建一个.mgit
  
  你可以在当前目录中看到每个仓库的源码，他们的路径可以通过  manifest.json 的 dest字段配置
  
  你也可以在 .mgit/source-git/ 下看到所有仓库的.git, 这是 MGit 对所有仓库的托管
  
- 本地测试成功后，你可以提交主仓库中的 manifest.json，推送主仓库的变更到远端
  
- 通过 `mgit init -g 主仓库地址` 命令初始化多仓库
  

#### 4、进一步了解 MGit

[常用命令](docs/use/common-commands.md)

[manifest文件介绍](docs/config/manifest.md)

[配置多仓库](docs/config/config-env.md) 

[了解更多](docs/references.md)


## 测试

单测在MGit仓库内的test文件夹下
新建单测文件，必须以‘test_’开头
执行单测：rake （如果报错尝试执行 bundle install）


## 如何贡献

欢迎开发者向 MGit 贡献代码。如果您开发了新功能或发现了 bug，欢迎给我们提交PR。

代码贡献要求：
1. 功能和实现应该具有通用性, 不是为了解决某个具体业务而定制的代码逻辑
2. 代码质量高，符合 Ruby 编码规范
3. 需要补充对应的单测 case

issues贡献： 如在使用中遇到问题，请在 https://github.com/baidu/m-git/issues 新建 issues 反馈问题。



