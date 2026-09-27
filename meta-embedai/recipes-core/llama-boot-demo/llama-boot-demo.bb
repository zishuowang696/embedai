SUMMARY = "EmbedAI boot smoke demo: one-shot llama.cpp inference on boot"
DESCRIPTION = "Runs a tiny one-shot CPU inference at boot and prints markers to the \
console. Used by the QEMU virtual board smoke test to verify the local-inference path in CI (no GPU)."
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = "file://llama-boot-demo.sh file://llama-boot-demo.service"

inherit systemd

RDEPENDS:${PN} += "llama-cpp llama-demo"

SYSTEMD_SERVICE:${PN} = "llama-boot-demo.service"
SYSTEMD_AUTO_ENABLE:${PN} = "enable"

do_install() {
    install -d ${D}${bindir}
    install -m 0755 ${UNPACKDIR}/llama-boot-demo.sh ${D}${bindir}/
    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${UNPACKDIR}/llama-boot-demo.service ${D}${systemd_system_unitdir}/
}
