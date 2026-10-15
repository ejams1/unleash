---
layout: default
title: Instalação — unleash
---

# Instalação

## Homebrew (mais fácil)

```bash
brew tap mateussiqueira/unleash
brew install unleash
```

Ou em um passo:
```bash
brew install mateussiqueira/unleash/unleash
```

## Download direto

```bash
REPO=ejams1/unleash      # troque por mateussiqueira/unleash quando o upstream receber as correções
mkdir -p ~/unleash
curl -fsSL "https://raw.githubusercontent.com/$REPO/main/unleash-standalone.sh" \
  -o ~/unleash/unleash-standalone.sh
chmod +x ~/unleash/unleash-standalone.sh
sudo ~/unleash/unleash-standalone.sh init
```

## De um pendrive USB (para o modo Recovery)

1. Formate um USB/SSD como **FAT32**, **APFS** ou **exFAT**
2. Copie a pasta `unleash` inteira para o drive — ou coloque o `unleash-standalone.sh` dentro de uma pasta (ex.: `SeuDrive/unleash/`). O backup é gravado um nível acima do script, então um arquivo solto na raiz do drive tentaria gravar em `/Volumes/.unleash-backup`
3. Inicialize no Recovery e execute de `/Volumes/SeuDrive/unleash`

## Via curl no Recovery (precisa de internet)

O Terminal do Recovery já é root, então não use `sudo`. Baixe **para dentro de
uma pasta**: o `backup` grava um nível acima do script, e um arquivo solto em
`/tmp` tentaria gravar em `/`, que é somente leitura no Recovery.

```bash
REPO=ejams1/unleash      # troque por mateussiqueira/unleash quando o upstream receber as correções
mkdir -p /tmp/unleash
curl -fsSL "https://raw.githubusercontent.com/$REPO/main/unleash-standalone.sh" \
  -o /tmp/unleash/unleash-standalone.sh
chmod +x /tmp/unleash/unleash-standalone.sh
cd /tmp/unleash

./unleash-standalone.sh version
./unleash-standalone.sh doctor            # caminho do script, módulos, modo Recovery
./unleash-standalone.sh check             # relatório antes de formatar
./unleash-standalone.sh test all          # simulação: não grava nada
./unleash-standalone.sh backup            # salvo em /tmp/.unleash-backup
./unleash-standalone.sh suppress          # ou: bypass (cria um usuário admin)
```

`/tmp` é um disco em memória no Recovery: copie `/tmp/.unleash-backup` para um
pendrive antes de reiniciar se quiser usar `restore` depois.

## Compilando a partir do código-fonte

```bash
git clone https://github.com/mateussiqueira/unleash.git
cd unleash
bash examples/build-standalone.sh
# Saída: unleash-standalone.sh (~3200 linhas)
```

## Verificando a instalação

```bash
./unleash version
# → unleash v2.0.0

./unleash doctor
# Executa diagnósticos pré-voo
```
