SUMMARY = "Qwen2.5-0.5B-Instruct GGUF model (Q2_K) for llama.cpp"
DESCRIPTION = "Pre-quantized Qwen2.5-0.5B-Instruct model in GGUF format (Q2_K, ~395MB), \
installed to /var/lib/llama/models for zero-config llama-server."
HOMEPAGE = "https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF"
SECTION = "devel/ai"
LICENSE = "Apache-2.0"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/Apache-2.0;md5=89aea4e17d99a7cacdbeed46a0096b10"

# 主源 huggingface.co；国内/受限网络回退 hf-mirror.com（同一文件、同一校验和）
SRC_URI = " \
    https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q2_k.gguf \
    https://hf-mirror.com/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q2_k.gguf \
"
SRC_URI[sha256sum] = "9ee36184e616dfc76df4f5dd66f908dbde6979524ae36e6cefb67f532f798cb8"

do_install() {
    install -d ${D}${localstatedir}/lib/llama/models
    install -m 0644 ${UNPACKDIR}/qwen2.5-0.5b-instruct-q2_k.gguf \
        ${D}${localstatedir}/lib/llama/models/
}

FILES:${PN} += "${localstatedir}/lib/llama/models/qwen2.5-0.5b-instruct-q2_k.gguf"
