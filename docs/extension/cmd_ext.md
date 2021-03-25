### 一、扩展指令


MGit 加载插件有**2种方式**：

- **ruby gem 包加载**
当运行 MGit 命令时，从所有的`ruby-gems`包中查找并加载 MGit 的插件，查找判定条件 gem 包中存在如下文件：
```
- m-git_plugin.rb
- mgit_plugin.rb
```
> Tips：插件功能开发完成后，打包为 gem 包后发布到 gem 源，MGit 执行命令时将自动被加载

- **inject 参数加载**
```
# 执行命令时加载插件
# path_to_plugin：可以是待加载的插件文件或文件夹，
# 如果是文件夹，则从中查找插件文件(m-git_plugin.rb、mgit_plugin.rb)并加载
$ mgit add --inject=${path_to_plugin}
```

### 1分钟极简扩展（以Demo多仓库示例，待修改demo url）
**需求：**假设我们要提供一个命令用于查看 MGit 管理的所有 Git 仓库，创建一个新的指令：hi
```
$ mgit hi //输出当前mgit管理的仓库列表
```
**Step0：**建议在一个新文件夹中拉取demo
```
mgit init -g https://github.com/baidu/m-git.git
```
**Step1：**新建一个文件：hi.rb （无所谓名称）
**Step2：**增加一个继承自 BaseCommand 类的子类`Hi`，指令默认使用子类的名称，可使用`self.cmd`方法重写
```
module MGit
  class Hi < BaseCommand
    def execute(argv)
	  # Do something for each repo.
      puts all_repos.map(&:name).join(',')
    end
  end
end
```

**测试：**
```
# inject 指向扩展命令的文件路径(或全路径)
mgit hi --inject=hi.rb
> m-git,DDParser
```