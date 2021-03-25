### config.yml 介绍

 config.yml 是 MGit 的配置文件；

 MGit的配置内容保存在多仓库目录下的`.mgit/config.yml`文件中，配置仅针对当前的多仓库生效；



- 通过 `$ mgit config --list`  可以查看当前config.yml中的配置

  ```ruby
  [是否将.git实体托管给MGit，托管后仓库内的.git目录是软链 (true/false)]
  managegit: true
  
  [MGit操作的最大并发数? (Integer)]
  maxconcurrentcount: (默认当前机器的逻辑 CPU 数)
  
  [是否按照配置表同步工作区? (true/false)]
  syncworkspace: true
  
  [同步工作区时回收的仓库是否保留到缓存中? (true/false)]
  savecache: false
  
  [是否开启日志打印，操作日志会收集到.mgit/log目录下? (true/false)]
  logenable: true
  
  [日志的打印级别, DEBUG = 0, INFO = 1, WARN = 2, ERROR = 3, FATAL = 4]
  loglevel: 0
  ```

- 通过 `$ mgit config --set` 可以对config.yml进行配置，如："mgit config -s maxconcurrentcount 20"

- 当前支持的几个配置项：

  | key                | 类型    | 描述                                                         | 默认值 |
  | ------------------ | :------ | ------------------------------------------------------------ | ------ |
  | managegit          | Boolean | 如果该配置为`true`, 那么在通过MGit下载新仓库时（`mgit sync -n`)，会将工作区仓库内的`.git`托管给MGit（将`.git`移动到`.mgit/source-git/`下）。若配置为`false`，则任何情况下都不操作`.git`, 如有`.git`已经被托管，则弹出到工作区。 | true  |
  | maxconcurrentcount | Integer | MGit操作的最大并发数.                                        | 当前机器的逻辑 CPU 数      |
  | syncworkspace      | Boolean | 当配置表发生改变的时候，工作区内的仓库可能和配置表不匹配，若配置为`true`，会将上次操作和本地操作依据的配置表做对比，将多余的仓库（如有的话）缓存到`/.mgit/source-git/.../cache`目录下。若配置为`false`，则不操作。 | true   |
  | savecache          | Boolean | 同步工作区时回收的仓库被放到缓存中后，若配置为`true`，则一直保留该工作区目录，若配置为`false`，则直接删除(`.git`被托管的仓库可以删除工作区，需要时导出即可)。该配置在`syncworkspace`为`false`时不生效。 | false  |
  | logenable          | Boolean | 是否开启日志打印，操作日志会收集到.mgit/log目录下            | true   |
  | loglevel           | Integer | 日志的打印级别, DEBUG = 0, INFO = 1, WARN = 2, ERROR = 3, FATAL = 4 | 1      |

  
  
 - 关于 managegit 与 syncworkspace 配置的详细说明
 
   建议配置：
      - managegit ：true
      - syncworkspace ： true
     
   在使用MGit管理多仓库时，当前分支dev-1分支 有 a、b、c 三个仓库；
   
   1、现在需要checkout到一个旧分支feature-1，feature-1只配置了 a、b仓库，此时c仓库会被MGit回收，不会展示在当前工作区（syncworkspace ： true 按照配置表同步工作区）
   
   2、但c仓库还有未推到远端的开发分支和stash的代码，MGit会托管暂时不用的c仓库，保证本地c仓库中的的代码不会丢失（ managegit: true 托管工作区）
   
   3、当再checkout到dev-1分支时，会将被托管的c仓库同步回工作区（syncworkspace ： true 按照配置表同步工作区）