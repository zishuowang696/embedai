# 兼容宿主 Python 3.10：meta-tegra 的 arm-trusted-firmware 用了 datetime.UTC（Python 3.11+）
# 这里用 timezone.utc 等价替换，行为一致。
def aislim_generate_build_timestamp(d):
    from datetime import datetime, timezone
    sde = d.getVar('SOURCE_DATE_EPOCH')
    if sde:
        return 'BUILD_MESSAGE_TIMESTAMP="\\\"{}\\\""'.format(
            datetime.fromtimestamp(int(sde), timezone.utc).strftime('%Y-%m-%d %H:%M:%S'))
    return ''

BUILDTIMESTAMP = "${@aislim_generate_build_timestamp(d)}"
