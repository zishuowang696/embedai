SUMMARY = "llama.cpp - LLM inference in C/C++ with HTTP server"
DESCRIPTION = "A C/C++ implementation of LLaMA-based large language models, \
with AArch64 NEON optimizations. Provides llama-cli and llama-server."
HOMEPAGE = "https://github.com/ggml-org/llama.cpp"
SECTION = "devel/ai"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://LICENSE;md5=223b26b3c1143120c87e2b13111d3e99"

SRC_URI = " \
    git://github.com/ggml-org/llama.cpp;protocol=https;branch=master \
    file://llama-server.service \
    file://llama-server.default \
"
SRCREV = "dcad77cc3b0865153f486327064fb0320a57a476"
PV = "b8933"

inherit cmake pkgconfig systemd

# Orin Nano（Cortex-A78AE, aarch64）：Release + AArch64 NEON
EXTRA_OECMAKE = "\
    -DCMAKE_BUILD_TYPE=Release \
    -DLLAMA_CPU_AARCH64=ON \
    -DLLAMA_BUILD_TESTS=OFF \
    -DLLAMA_OPENSSL=OFF \
    -DBUILD_SHARED_LIBS=OFF \
"

# 只编译需要的目标：避免 cmake --install 去装未构建的 example 导致失败
do_compile() {
    cmake --build ${B} --target llama-cli --target llama-server
}

do_install() {
    install -d ${D}${bindir}
    install -m 0755 ${B}/bin/llama-cli ${D}${bindir}/
    install -m 0755 ${B}/bin/llama-server ${D}${bindir}/

    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${WORKDIR}/llama-server.service ${D}${systemd_system_unitdir}/

    install -d ${D}${sysconfdir}/default
    install -m 0644 ${WORKDIR}/llama-server.default ${D}${sysconfdir}/default/llama-server

    install -d ${D}${localstatedir}/lib/llama/models
}

SYSTEMD_SERVICE:${PN} = "llama-server.service"
# 默认不自动启动：等模型就位后再 systemctl enable/start，避免无模型时反复重启
SYSTEMD_AUTO_ENABLE:${PN} = "disable"

FILES:${PN} += "\
    ${bindir}/llama-cli \
    ${bindir}/llama-server \
    ${systemd_system_unitdir}/llama-server.service \
    ${sysconfdir}/default/llama-server \
    ${localstatedir}/lib/llama/models \
"

RDEPENDS:${PN} += "libstdc++ libgomp"
