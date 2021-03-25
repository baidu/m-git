### hook

#### 一、什么是hook

hook是在MGit 仓库中特定事件触发后被调用的脚本。hook最常见的使用场景包括根据仓库状态改变项目环境、接入持续集成工作流等。 由于脚本是可以完全定制，所以你可以用hook来自动化或者优化你开发工作流中任意部分。

#### 二、MGit的hook

hook脚本位于多仓库目录下的`/.mgit/hooks`内，下表列出个各hook的作用

| hook脚本              | 作用                                                         |
| --------------------- | ------------------------------------------------------------ |
| pre_hook.rb           | 指令执行前hook(执行时机较早，内部只能获取当前指令和多仓库根目录) |
| post_hook.rb          | 指令执行后hook                                               |
| pre_exec_hook.rb      | 指令执行前hook(内部除当前指令和多仓库根目录外，还可获取执行仓库的 |
| manifest_hook.rb      | mgit读取配置文件前执行的hook                                 |
| post_download_hook.rb | mgit sync下载新仓库后执行的hook                              |
| pre_push_hook.rb      | mgit push前执行的hook(类似pre_exec_hook)                     |

【注意】执行顺序：

1. mgit指令pre_hook
2. mgit多仓库pre_hook
3. manifest_hook
4. pre_exec_hook/pre_push_hook/post_download_hook
5. git前置hook
6. git后置hook
7. mgit多仓库post_hook
8. mgit指令post_hook



如下代码是   pre_hook.rb 的模板:  

```

#coding=utf-8
module MGitTemplate
  class PreHook
    # hook接口，用于接受本次指令执行前的数据
    #
    # @param cmd [String] 本次执行指令
    #
    # @param opts [String] 本次执行指令参数
    #
    # @param mgit_root [String] mgit根目录
    #
    def self.run(cmd, opts, mgit_root)
    
    end
  end
end
```

