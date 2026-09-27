#!/bin/sh
# 启动冒烟：一次性 CPU 推理，向控制台打印标记，然后自动关机（让 runqemu 及时退出）。
# 标记： LLAMA_BOOT_DEMO_BEGIN / LLAMA_BOOT_DEMO_END（成功）
#        LLAMA_BOOT_DEMO_NO_MODEL（找不到模型）
#        LLAMA_BOOT_DEMO_WATCHDOG（推理超时，看门狗强制关机）
MODEL="$(find /var/lib/llama/models /home/root/models /root /home -maxdepth 2 -name '*.gguf' -type f 2>/dev/null | head -n1)"
echo "LLAMA_BOOT_DEMO_BEGIN model=${MODEL:-none}"

poweroff_now() { systemctl poweroff 2>/dev/null || /sbin/poweroff -f 2>/dev/null || poweroff -f; }

# 看门狗：推理若卡死，超时强制关机，保证 runqemu 能退出、CI 不空等
( sleep 900; echo "LLAMA_BOOT_DEMO_WATCHDOG"; poweroff_now ) &

if [ -z "$MODEL" ]; then
    echo "LLAMA_BOOT_DEMO_NO_MODEL"
else
    /usr/bin/llama-cli -m "$MODEL" -c 512 -ngl 0 -p "Reply with exactly: EMBEDAI_OK" -n 8 \
        < /dev/null 2>&1 | tail -n 40
fi
echo "LLAMA_BOOT_DEMO_END"
sync
poweroff_now
