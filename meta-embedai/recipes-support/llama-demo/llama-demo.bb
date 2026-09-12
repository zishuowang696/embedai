SUMMARY = "EmbedAI llama.cpp demo CLI"
DESCRIPTION = "One-shot CLI for chat / HTTP server / benchmark / model download on top of llama-cpp."
SECTION = "devel/ai"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = "file://llama-demo.sh"

RDEPENDS:${PN} += "llama-cpp bash wget"

do_install() {
    install -d ${D}${bindir}
    install -m 0755 ${UNPACKDIR}/llama-demo.sh ${D}${bindir}/llama-demo
}
