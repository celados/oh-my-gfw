# Render from projects/oh-my-gfw with:
# latch render "{ file: 'network/devices.env.tpl', output: 'network/devices.env', format: 'compose-env' }"
# The rendered file contains credentials and is gitignored.
# vault: home-network Huawei K662c
HUAWEI_K662C_USERNAME={{ bw://5437c196-54a9-4adf-96c5-32fc8f41acef/username }}
HUAWEI_K662C_PASSWORD={{ bw://5437c196-54a9-4adf-96c5-32fc8f41acef/password }}
# vault: home-network ZTE F7615TV3
ZTE_F7615TV3_USERNAME={{ bw://0b0e354f-c720-4e03-ad92-7f1f50620a7a/username }}
ZTE_F7615TV3_PASSWORD={{ bw://0b0e354f-c720-4e03-ad92-7f1f50620a7a/password }}
