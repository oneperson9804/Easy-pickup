# 取件记录迁移工具

将受支持版本的取件记录、识别规则和排序设置导出为易取件 v1 JSON 文件，通过系统文件选择器保存。

## 使用

受支持版本为应用 `com.sidutech.express` 的 code56，迁移包为同签名的 code57。

1. 在受支持版本上安装签名一致的迁移包，保留现有应用数据。
2. 打开桌面入口“导出旧版数据”，选择文件位置并保存。
3. 打开易取件，在“设置 → 备份与恢复”导入文件。
4. 核对待取、已取、详细位置、站点顺序和规则后，再移除原应用。

迁移包需要与已安装版本保持签名一致。若系统提示签名冲突，请保留有记录的应用，先核对版本与签名。

## 文件内容

- `format=easy-pickup`，`schemaVersion=1`；时间使用 Unix 毫秒。
- 记录 ID 由设备保存的随机迁移标识和原记录 ID 组成，重复导出保持稳定。
- `received` 对应已取状态，`received_date` 对应已取时间，`date` 对应到件时间。缺失时间保留原值，相关信息记入 `legacyMigration.warnings`。
- 已删除记录使用导出时间填入 `deleted_at`，以保留删除状态；具体时间约定记入元数据。
- 空取件码保留为空。空站点归入“待确认站点”，原地址另存于元数据。
- 详细位置保存到每条记录的 `detail_address`。
- 地址和公司识别规则转换为本地匹配规则，站点顺序和取件码排序保存到设置。
- 取件提醒在新应用中按需开启；静态码可在码夹中添加。

备份文件包含取件码和原始通知，请自行保管。

## 构建

使用受支持版本的 Android 项目快照、Apktool 3、JDK 21、Android SDK platform36/build-tools36，以及与已安装版本一致的签名密钥。脚本在新工作目录中构建并输出迁移包。

以下命令在 Linux 或 WSL 中运行：

```sh
export JAVA_HOME=/path/to/jdk-21
export PATH="$JAVA_HOME/bin:$PATH"
# 在当前进程设置 EASY_MIGRATION_KEYSTORE_PASS；独立私钥密码使用 EASY_MIGRATION_KEY_PASS。
python3 tools/legacy-migration/build.py \
  --legacy-project /private/path/to/code56-project \
  --sdk /path/to/android-sdk --jdk "$JAVA_HOME" \
  --apktool /path/to/apktool.jar \
  --work /private/new-migration-work \
  --keystore /private/path/to/old-signing.keystore --alias YOUR_ALIAS \
  --output /private/output/passage-migration-v57.apk
```

构建材料和签名配置由应用维护者在本地准备。输出文件用于导出取件数据，新应用使用独立的安装包。
