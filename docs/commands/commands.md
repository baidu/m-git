
## Command-line Reference
参考：https://guides.cocoapods.org/terminal/commands.html#pod_spec_lint


# Brief Description Of Commands

## Initalizing
+ mgit
+ config     用于更新多仓库配置信息。

## Creating && Workspace
+ init       初始化多仓库目录。
+ sync       根据配置表(从远端或本地)同步仓库到工作区，包括被锁定仓库，已经在工作的不作处理（默认不执行pull）。
+ info       输出指定仓库的信息。
+ clean      对指定或所有仓库执行"git add . && git reset --hard"操作，强制清空暂存区和工作区。
+ delete     删除指定单个或多个仓库（包含被管理的.git文件和工程文件以及跟该.git关联的所有缓存）。

## Snapshotting
+ add        将文件改动加入暂存区。
+ status     输出所有仓库的状态。包括："分支"，"暂存区"，"工作区"，"特殊（未跟踪和被忽略）"，"冲突"。
+ commit     将修改记录到版本库。
+ reset      将当前HEAD指针还原到指定状态。

## Branching
+ branch     列出，创建和删除分支。
+ checkout   切换分支或恢复工作区改动。
+ merge      合并两个或多个开发历史。
+ stash      使用git stash将当前工作区改动暂时存放起来。
+ tag        增删查或验证标签。增加标签示例：mgit tag -a 'v0.0.1' -m 'Tag description message'
+ log        输出指定仓库的提交历史。

## Trunk
+ fetch      从远程仓库下载数据对象和引用。
+ pull       从仓库或本地分支获取数据并合并。
+ rebase     重新将提交应用到其他基点，该命令不执行lock的仓库。
+ push       更新远程分支和对应的数据对象。

## Addition
+ forall     对多仓库批量执行指令。
