#!/bin/sh
# 启动冒烟：一次性 CPU 推理，向控制台打印标记，供 runqemu 启动测试抓取。
# 标记： LLAMA_BOOT_DEMO_BEGIN / LLAMA_BOOT_DEMO_END（成功）
#        LLAMA_BOOT_DEMO_NO_MODEL（找不到模型）
MODEL="$(find /var/lib/llama/models /home/root/models /root /home -maxdepth 2 -name '*.gguf' -type f 2>/dev/null | head -n1)"
echo "LLAMA_BOOT_DEMO_BEGIN model=${MODEL:-none}"
if [ -z "$MODEL" ]; then
    echo "LLAMA_BOOT_DEMO_NO_MODEL"
    echo "LLAMA_BOOT_DEMO_END"
    exit 0
fi
/usr/bin/llama-cli -m "$MODEL" -c 512 -ngl 0 -p "Reply with exactly: EMBEDAI_OK" -n 16 \
    < /dev/null 2>&1 | tail -n 40
echo "LLAMA_BOOT_DEMO_END"
