### 1. manifest 配置介绍

manifest.json 配置表定义了多仓库管理所需的仓库信息，采用json格式，示例如下：

```ruby
{
  "remote": "https://github.com/baidu",//远程仓库地址
  "version":1, //配置文件版本
  "mgit-excluded": false,
  "dest": "Sources", //本地仓库相对mgit根目录存放路径
  "repositories": { //源码列表，包含git仓库和非git仓库
	"MainApp": {
      "remote-path": "mainapp" //远程仓库名，对于需要mgit管理的仓库是必需字段。此时git地址为：https://github.com/baidu/mainapp
      "config-repo": true //指定该仓库为配置仓库，即包含本配置表的仓库，仅允许指定一个仓库
    },
    "Watch": {
      "remote-path": "watch"
      "dest":"temp/test" //可选，覆盖最外层定义，在mgit根目录下仓库的父目录。该仓库本地路径为"<mgit根目录>/temp/test/Watch"
    },
    "BBAAccount": {
      "remote-path": "bbaaccount",
      "abs-dest":"/Users/someone/baidu/temp/my_account" //仓库本地完整路径（指定后dest无效）
    },
    "Script": {
      "remote-path": "script",
      "remote": "https://github.com/some_script",//可选，覆盖最外层定义
      "lock": {
	    "branch":"my_branch"//当前分支
	    或"tag":"tag1"//tag
	    或"commit_id":"123456"//HEAD指向的commit id
	  }//锁定某仓库状态，每次执行指令时会保持该仓库为指定的状态
    },
    "Some_Repo": {
      "remote-path": "some_repo",
      "mgit-excluded": true//指定不进行多仓库管理，可选
    },
    //本地git仓库或非git仓库（mgit不操作）
    "New_Repo": {
      "dest": "Some/Dir",
      "mgit-excluded": true
    }，
    "Test_Repo": {
      "dest": "Some/Dir2",
      "dummy": true //（2.3.0已废弃）指定该仓库为占位仓库（mgit不操作，EasyBox组装器也不使用）
    }
  }
}
```



### 2. manifest 配置中的具体字段介绍

#### 2.1 一级字段

| 字段名          | 说明                                                         | 必要性 | 值类型               |
| :-------------- | :----------------------------------------------------------- | :----- | :------------------- |
| `remote`        | 远程仓库git地址的根目录。注意，完整地址为`<remote>/<remote-path>`。 | 必需   | `String`             |
| `version`       | 配置文件版本。                                               | 必需   | `Number`             |
| `dest`          | 在mgit根目录下仓库的父目录，此时完整本地目录为：`<mgit根目录>/<dest>/<repo_name>`。 | 必需   | `String`             |
| `mgit-excluded` | 指定为`true`则不被mgit纳入多仓库管理，即mgit不会操作该仓库。 | 可选   | `Bool`               |
| `repositories`  | 源码列表。                                                   | 必需   | `JSON<String, JSON>` |



####  2.2 `repositories`内的Json数据

| 字段名        | 说明                                                         | 值类型 |
| :------------ | :----------------------------------------------------------- | :----- |
| `<repo_name>` | 仓库唯一标识，值为该仓库的配置。在`dest`生效时，为本地仓库目录名，此时完整本地目录为：`<mgit根目录>/<dest>/<repo_name>`。 | `JSON` |



#### 2.3. 仓库配置字段

| 字段名                | 说明                                                         | 必要性                                                       | 值类型   |
| :-------------------- | :----------------------------------------------------------- | :----------------------------------------------------------- | :------- |
| `remote-path`         | 远程仓库git地址相对路径。注意，完整的远程地址为`<remote>/<remote-path>`。 | 有条件可选：在不显式指定`mgit-excluded`为`true`的情况下（即希望该仓库纳入mgit管理的话），是必须字段，否则可选。 | `String` |
| `remote`              | 远程仓库地址根目录，如果指定则覆盖一级字段的`remote`。注意，完整的远程地址为`<remote>/<remote-path>`。 | 可选                                                         | `String` |
| `lock`                | 指定后会锁定仓库状态，每次执行指令时会保持该仓库为锁定状态。状态可以指定`branch`, `tag`, `commit_id`中的一个，如`lock: { "branch": "master" }`。 | 可选                                                         | `Json`   |
| `dest`                | 本地仓库相对mgit根目录存放的父目录，如果指定则覆盖一级字段的`dest`。此时完整本地目录为：`<mgit根目录>/<dest>/<repo_name>`。 | 可选                                                         | `String` |
| `abs-dest`            | 本地仓库的完整存放路径，如果指定则`dest`失效，此时仓库完整的本地路径为`<abs-dest>`。 | 可选                                                         | `String` |
| `config-repo`         | 如果指定为`true`则表明该仓库为包含该配置文件的配置仓库，最多只能指定一个。注意，指定了该仓库后，某些mgit操作会优先处理该仓库，如`checkout`,`merge`，`pull`。 | 可选                                                         | `Bool`   |
| `mgit-excluded`       | 指定为`true`则mgit不操作，此处指定会覆盖一级字段的`mgit-excluded`。 | 可选                                                         | `Bool`   |
| `[2.3.0已废弃] dummy` | 指定为`true`则表明该仓库是占位仓库，不受mgit操作，同时EasyBox组装器也不使用它的**源码**，单纯用于记录仓库信息，如一些完全二进制的三方库。<br><br>**提示**：指定`dummy:true`后，则默认指定`mgit-excluded:true`（如果显示指定了`mgit-excluded:false`，依然将其置为`true`）。该字段用于配合EasyBox进行工程组装，日常使用无需添加。 | 可选                                                         | `Bool`   |



- **mgit根目录**是指mgit初始化的目录，在该目录下存在`.mgit`隐藏文件。
- 配置表文件名必须是`manifest.json`
- 配置表中同名字段覆盖优先级：仓库配置 > 全局配置。
- 对于值为`Bool`类型的字段，缺省意味着该字段值为`false`。
- 采用包含配置表的中央仓库的方式管理多仓库时，需要将配置仓库的配置也描述在配置表中。



### 3. 本地配置表 local_manifest

当你想在本地调试时，可以通过创建`local_manifest.json`临时修改多仓库配置；可以在不修改`manifest.json`的情况下对配置进行调整；

可以选择以下方式创建 local_manifest.json：


- 通过 `migt init` 命令自动创建 

    - 执行命令时不带参数`-l`参数
    
      将自动在配置仓库创建不生效的`local_manifest.json`，内容为：
    
      ```ruby
      {
        "repositories": {
         // 可自行根据需要添加/修改仓库配置
        }
      }
      ```

    - 执行命令时添加参数`-l`
    
      则在配置仓库创建`local_manifest.json`，此时该文件只包含配置仓库信息：
    
      ```ruby
      // 此配置的含义：让mgit只管理配置仓库，其余仓库均不管理，主要用于简化壳工程初始化。
      {
        "mgit-excluded": true,
        "repositories": {
          "config_repo_name": {
            "mgit-excluded": false
           }
        }
      }
      ```
  


-  通过 `mgit config` 命令创建

    指定一个目录，在该目录下创建`local_manifest.json`，若目录不存在则自动创建。如：

    ```ruby
    $ mgit config -c /a/b/c
    
    ```

    **注意**：

    * `/a/b/c`为包含配置文件的文件夹目录，此时生成配置文件`/a/b/c/local_manifest.json`
    * 如果未传入值，如：`mgit config -c`，那么若配置仓库存在的话，会在配置仓库中创建空的本地配置文件。


-  手动创建 local_manifest.json

    * 手动新建配置文件`local_manifest.json`，放到任意位置，执行以下指令将其托管给mgit：

      ```
      //注意，此后如果local_manifest.json位置发生了移动，需要重新执行该指令使其生效。
      $ mgit config -u <path_to>/local_manifest.json
      ```

    * 在不执行指令的情况下，可手动创建`local_manifest.json`并将其放置于下列目录即可自动生效:

      将创建的local_manifest.json 放到`manifest.json`所在目录 或 `.mgit/source-config`文件夹内 即可生效

  

### 4、 对local_manifest.json 校验与合并

- `local_manifest.json`文件的字段与`manifest.json`完全一致，唯一区别是不会对它做字段合法性校验，对于不需要覆盖的字段可以缺省。
- 执行mgit指令时，会将`manifest.json`和`local_manifest.json`合并，配置文件中的字段会被本地配置文件中定义的对应字段覆盖（`repositories`字段除外，而是仓库配置内的对应字段被覆盖），如：



```ruby
// manifest.json:
{
  "remote":"https://github.com/baidu",
  "version":1,
  "dest":"Sources",
  "repositories": {
    "TestRepo1": {
      "remote-path":"test1.git",
       "mgit-excluded": false
    }
  }
}


// local_manifest.json:
{
    "remote":"https://github.com/baidu", //覆盖原定义
   "repositories": {
      //将manifest.json内定义的TestRepo1排除管理
       "TestRepo1": {
           "mgit-excluded": true
       }，
       //添加一个新仓库，配置完成后执行mgit sync -n可下载该仓库
       "TestRepo2": {
          "remote-path":"test.git"
       }
   }
}

// 将合并为：
{
  "remote":"https://github.com/baidu", //被覆盖
  "version":1,
  "dest":"Sources",
  "repositories": {
    "TestRepo1": {
      "remote-path":"test1.git",
       "mgit-excluded": true //被覆盖
    },
    //被添加
    "TestRepo2": {
      "remote-path":"test.git"
    }
  }
}
```

