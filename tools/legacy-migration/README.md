# 旧版取件记录导出工具

此目录只有新增导出器的原创 Java 源码及构建脚本，不含旧版反编译工程、旧 SDK、用户记录、APK 或签名材料。

工具运行在旧应用 `com.sidutech.express` 自己的沙箱内，通过系统文件选择器保存易取件 v1 JSON 备份，不需要 root 或存储管理权限。它不修改旧数据库，也不迁移账号、商业额度和平安打卡。

## 用户操作

1. 在现有 code56 免费版上安装同签名的 code57 迁移包，保留旧应用数据。
2. 打开新增的桌面入口“导出旧版数据”，保存 JSON 文件。
3. 打开易取件，在“设置 → 备份与恢复”导入文件。
4. 核对待取、已取、站点顺序和规则后，再决定是否移除旧版。

若安装提示签名冲突，请停止操作，不要卸载有记录的旧应用。迁移包只能覆盖签名一致的旧版。

## 数据约定

- `format=easy-pickup`，`schemaVersion=1`；时间使用 Unix 毫秒。
- 记录 ID 包含保存在旧版本机的随机迁移标识和原行 ID，重复导出保持稳定。
- `received` 对应 `collected_at` 是否为 null；`received_date` 为已取时间，`date` 为到件时间。缺失时间保留原值，并记入 `legacyMigration.warnings`，不编造历史时间。
- 原版只有删除标记，没有删除时刻；已删除记录的 `deleted_at` 使用导出时间表示其状态，并在元数据中说明。
- 空取件码原样保留。空站点归入“待确认站点”，原地址保存在 `legacyMigration.originalDetails`。
- 原 `detail_address` 迁入每条记录的正式字段，同时在元数据中保留原值。
- 地址和公司规则是旧版的字符串集合，迁为匹配文字与显示文字相同的本地规则。站点顺序和取件码排序迁入设置。旧提醒权限不自动开启。
- 静态码数组为空：旧身份码页面是第三方快捷入口，不持有可导出的身份凭证。

## 构建

需要原 code56 Apktool 目录、Apktool 3、JDK 21、Android SDK platform36/build-tools36，以及与旧版一致的签名密钥。构建脚本复制旧目录到新的工作目录，绝不覆盖原目录或已有输出。

```sh
export JAVA_HOME=/path/to/jdk-21
export PATH="$JAVA_HOME/bin:$PATH"
# 在当前进程安全设置 EASY_MIGRATION_KEYSTORE_PASS；如需不同私钥密码，设置 EASY_MIGRATION_KEY_PASS。
python3 tools/legacy-migration/build.py \
  --decoded /private/path/to/code56-decoded \
  --sdk /path/to/android-sdk --jdk "$JAVA_HOME" \
  --apktool /path/to/apktool.jar \
  --work /private/new-migration-work \
  --keystore /private/path/to/old-signing.keystore --alias YOUR_ALIAS \
  --output /private/output/passage-migration-v57.apk
```

旧应用工程不适合公开整包上传，构建所需材料由原应用维护者在本地提供。迁移包属于过渡工具，不是易取件的新版本。
