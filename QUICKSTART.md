# unleash — Quick Reference

Keep this on your SSD alongside the script.

## First time

1. Boot to Recovery (Apple Silicon: hold Power, Intel: Cmd+R)
2. Open Terminal → `chmod +x "/Volumes/YourSSD/unleash/unleash"`
3. Run → `"/Volumes/YourSSD/unleash/unleash"`
4. Pick "Full bypass" from the menu

## Sem SSD (no Recovery, com internet)

```bash
REPO=ejams1/unleash
mkdir -p /tmp/unleash && cd /tmp/unleash
curl -fsSL "https://raw.githubusercontent.com/$REPO/main/unleash-standalone.sh" -o unleash-standalone.sh
chmod +x unleash-standalone.sh

./unleash-standalone.sh doctor        # confere caminho, módulos e modo Recovery
./unleash-standalone.sh test all      # simulação: não grava nada
./unleash-standalone.sh backup        # salvo em /tmp/.unleash-backup
./unleash-standalone.sh suppress      # ou bypass (cria usuário admin + pula o Setup Assistant)
```

Pasta obrigatória: o `backup` grava um nível acima do script, e `/` é somente
leitura no Recovery. `/tmp` é disco em memória — copie `/tmp/.unleash-backup`
para um pendrive antes de reiniciar se quiser usar `restore` depois.

## Common scenarios

| Você quer... | Comando |
|---|---|
| Bypass completo (cria usuário admin) | `./unleash bypass` |
| Só silenciar o MDM (sem criar usuário) | `./unleash suppress` |
| Consertar depois de atualizar macOS | `sudo ./unleash heal` |
| Nunca mais pensar nisso | `sudo ./unleash persist` + `sudo ./unleash whitelist` |
| Saber se vai travar após formatar | `sudo ./unleash check` |
| Vigiar MDM em tempo real | `sudo ./unleash monitor` |
| Instalar monitor para sempre | `sudo ./unleash monitor-install` |
| Limpeza pós-bypass (já logado) | `sudo ./unleash harden` |
| Varredura completa | `sudo ./unleash audit` |
| Voltar ao normal | `./unleash restore` |

## Aliases

`by` = bypass, `sv` = suppress, `fw` = firewall, `wl` = whitelist,
`st` = status, `mn` = monitor, `mn-st` = monitor-status

## Avisos

- **Não** rode `profiles renew` — isso reativa o MDM
- **Não** use "Apagar Conteúdo e Ajustes" — isso limpa o bypass
- Após formatar (wipe), rode o bypass de novo do Recovery
- Migration Assistant traz o MDM de volta — sempre rode `suppress` depois
