#!/usr/bin/env python3
"""Portuguese O&M Hotline Training deck for Huawei Cloud (HCS 8.6.1).

Covers: architecture, services, SR/ticket process, ITR flow, TAC email,
mailbox handling, common operations, best practices. ~1 hour training.
"""

import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                 '..', '..', '..', 'templates', 'ppt'))
from huawei_ppt import *

OUT_DIR = os.path.dirname(os.path.abspath(__file__))


def main():
    prs, layouts = new_deck()

    # ═══════════════════════════════════════════════════════════════
    # SLIDE 1 — Title
    # ═══════════════════════════════════════════════════════════════
    title_slide(prs, layouts,
                "Treinamento O&M Hotline Huawei Cloud",
                "HCS 8.6.1 | Operações & Manutenção",
                "Módulo 1 | Português")

    # ═══════════════════════════════════════════════════════════════
    # SLIDE 2 — Agenda
    # ═══════════════════════════════════════════════════════════════
    s = content_slide(prs, layouts, "Agenda do Treinamento")
    text_box(s, "1. Arquitetura HCS 8.6.1\n"
                "2. Famílias de Serviços e Acronimos\n"
                "3. Processo de Abertura de SR\n"
                "4. Notificação ao TAC e Template de SR\n"
                "5. Processo ITR (Issue To Resolve)\n"
                "6. Matriz de Escalação\n"
                "7. Operações Comuns de O&M\n"
                "8. Melhores Práticas e Checklist",
             Inches(LEFT_MARGIN), Inches(TOP_CONTENT),
             Inches(CONTENT_WIDTH), Inches(4.5), 16, DARK)

    # ═══════════════════════════════════════════════════════════════
    # CHAPTER 1 — Arquitetura
    # ═══════════════════════════════════════════════════════════════
    chapter_slide(prs, layouts, "Arquitetura HCS 8.6.1",
                  "Plano de Gestão e Plano de Dados")

    # SLIDE — Arquitetura Overview
    s = content_slide(prs, layouts, "Visão Geral da Arquitetura")
    text_box(s,
        "O HCS (Huawei Cloud Stack) é uma solução de nuvem privada on-premise.\n\n"
        "Componentes principais:\n"
        "  • ManageOne — plataforma de operações unificada (O&M)\n"
        "  • ServiceCenter — portal de autoserviço e catálogo de serviços\n"
        "  • FusionSphere — virtualização (compute, storage, network)\n"
        "  • OMBase — banco de dados de operações\n\n"
        "Versão alvo: HCS 8.6.1\n"
        "Objetivo: equipe autorando conteúdo a partir de 01/09",
        Inches(LEFT_MARGIN), Inches(TOP_CONTENT),
        Inches(CONTENT_WIDTH), Inches(4.5), 14, DARK)

    # SLIDE — Plano de Gestão vs Dados
    s = content_slide(prs, layouts, "Plano de Gestão vs Plano de Dados")
    add_table(s,
        ["Camada", "Componentes", "Função"],
        [
            ["Gestão", "ManageOne, OMBase", "O&M, monitoramento, billing"],
            ["Gestão ServiceCenter", "ServiceCenter, Catalog", "Autoserviço, aprovisionamento"],
            ["Dados — Compute", "FusionCompute, ECS", "VMs, containers, auto scaling"],
            ["Dados — Storage", "FusionStorage, EVS, OBS", "Block, object, file storage"],
            ["Dados — Network", "VPC, EIP, ELB", "Rede virtual, IP, balanceamento"],
        ])
    callout(s, 'infobox',
            "ManageOne é a plataforma de operações — não é um serviço cloud. "
            "ServiceCenter é o portal de autoserviço.",
            top=5.2)

    # ═══════════════════════════════════════════════════════════════
    # CHAPTER 2 — Serviços (expandido — a parte mais importante)
    # ═══════════════════════════════════════════════════════════════
    chapter_slide(prs, layouts, "Serviços Cloud",
                  "Famílias, detalhes e o que o hotline precisa saber")

    # SLIDE — Famílias de Serviços (visão geral)
    s = content_slide(prs, layouts, "Famílias de Serviços Cloud")
    add_table(s,
        ["Família", "Serviços Principais", "Qtd"],
        [
            ["Computação", "ECS, IMS, AS, CCE", "4"],
            ["Armazenamento", "EVS, OBS, SFS, HBR", "4"],
            ["Rede", "VPC, EIP, ELB, NAT, VPN, DNS", "6"],
            ["Banco de Dados", "RDS, GaussDB, DRS, DDS", "4"],
            ["Segurança", "Anti-DDoS, WAF, IAM, KMS", "4"],
        ])
    callout(s, 'tip',
            "O hotline precisa saber o nome oficial do serviço para roteamento do SR. "
            "Cada família tem características e problemas próprios — veremos a seguir.",
            top=5.2)

    # SLIDE — Computação em detalhe
    s = content_slide(prs, layouts, "Computação — Serviços em Detalhe")
    add_table(s,
        ["Svc", "O Que É", "Quando Usar", "O Que Verificar Primeiro"],
        [
            ["ECS", "Servidor virtual que você aluga na nuvem",
             "Apps web, APIs, processamento de dados",
             "Status da VM, quotas, eventos do sistema"],
            ["IMS", "Imagem/template para criar VMs rápido",
             "Deploy repetível e padronizado",
             "Imagem existe? Versão correta?"],
            ["AS", "Adiciona/remove VMs automaticamente",
             "Picos de tráfego, workloads variáveis",
             "Políticas de scaling, min/max instâncias"],
            ["CCE", "Kubernetes gerenciado (containers)",
             "Microserviços, aplicações modernas",
             "Status dos pods, nós prontos, quotas"],
        ],
        col_widths=[Inches(0.8), Inches(3.5), Inches(3.2), Inches(4.2)])
    callout(s, 'infobox',
            "ECS é o serviço mais comum — a maioria dos SRs de computação começa aqui. "
            "Sempre confirmar: nome da VM, flavor (CPU/RAM) e status atual.",
            top=5.2)

    # SLIDE — Armazenamento em detalhe
    s = content_slide(prs, layouts, "Armazenamento — Serviços em Detalhe")
    add_table(s,
        ["Svc", "O Que É", "Quando Usar", "O Que Verificar Primeiro"],
        [
            ["EVS", "Disco virtual anexado a uma VM",
             "Discos de sistema e dados",
             "Capacidade, IOPS, está anexado?"],
            ["OBS", "Armazenamento de objetos (tipo S3)",
             "Backups, mídia, arquivos estáticos",
             "AK/SK válidas? Bucket existe?"],
            ["SFS", "Sistema de arquivos compartilhado",
             "Arquivos compartilhados entre VMs",
             "Mount point, quota, performance"],
            ["HBR", "Backup e recuperação híbrida",
             "DR, backups de VMs e dados",
             "Job rodou? Restore foi testado?"],
        ],
        col_widths=[Inches(0.8), Inches(3.5), Inches(3.2), Inches(4.2)])
    callout(s, 'warning',
            "Disco cheio (>90%) é o problema mais comum de armazenamento. "
            "Verificar sempre capacidade e IOPS antes de escalar.",
            top=5.2)

    # SLIDE — Rede em detalhe
    s = content_slide(prs, layouts, "Rede — Serviços em Detalhe")
    add_table(s,
        ["Svc", "O Que É", "Quando Usar", "O Que Verificar Primeiro"],
        [
            ["VPC", "Rede privada isolada na nuvem",
             "Todos os recursos cloud",
             "Subnets, route tables, SG"],
            ["EIP", "IP público para acesso externo",
             "Serviços voltados à internet",
             "EIP associada? Reachability"],
            ["ELB", "Distribui tráfego entre servidores",
             "Alta disponibilidade, scaling",
             "Health checks, backends saudáveis?"],
            ["NAT", "VMs privadas acessam internet",
             "VMs sem EIP que precisam de internet",
             "Regras NAT, gateway ativo?"],
            ["VPN", "Túnel seguro on-premise ↔ nuvem",
             "Conexão híbrida, acesso remoto",
             "Tunnel up? Rotas corretas?"],
            ["DNS", "Resolução de nomes em IPs",
             "Todos os serviços com nomes",
             "Zona existe? Records corretos?"],
        ],
        col_widths=[Inches(0.8), Inches(3.5), Inches(3.2), Inches(4.2)])
    callout(s, 'infobox',
            "Problemas de rede quase sempre envolvem Security Group ou VPC. "
            "Confirmar SG (portas abertas) e route table antes de escalar.",
            top=5.2)

    # SLIDE — Banco de Dados em detalhe
    s = content_slide(prs, layouts, "Banco de Dados — Serviços em Detalhe")
    add_table(s,
        ["Svc", "O Que É", "Quando Usar", "O Que Verificar Primeiro"],
        [
            ["RDS", "BD relacional gerenciado (MySQL, PG)",
             "Apps que usam SQL padrão",
             "Slow log, conexões, status HA"],
            ["GaussDB", "BD de alta performance da Huawei",
             "Grande escala, OLTP",
             "Performance, sync, conexões"],
            ["DRS", "Replicação e migração de dados",
             "Migração entre bancos, sync contínua",
             "Lag de sync, status do job"],
            ["DDS", "Banco de documentos (NoSQL)",
             "Apps com schema flexível",
             "Queries lentas, índices, conexões"],
        ],
        col_widths=[Inches(0.8), Inches(3.5), Inches(3.2), Inches(4.2)])
    callout(s, 'tip',
            "RDS é o BD mais usado. Problemas comuns: slow queries e limite de conexões. "
            "Pedir sempre o slow log e o número de conexões ativas.",
            top=5.2)

    # SLIDE — Segurança em detalhe
    s = content_slide(prs, layouts, "Segurança — Serviços em Detalhe")
    add_table(s,
        ["Svc", "O Que É", "Quando Usar", "O Que Verificar Primeiro"],
        [
            ["Anti-DDoS", "Proteção contra ataques de negação",
             "Serviços públicos expostos",
             "Tráfego anormal, evento de ataque"],
            ["WAF", "Firewall de aplicação web",
             "Sites e APIs web",
             "Regras WAF, falsos positivos, logs"],
            ["IAM", "Gestão de identidade e acesso",
             "Todos os serviços",
             "Políticas, roles, permissões"],
            ["KMS", "Gestão de chaves de criptografia",
             "Dados sensíveis, compliance",
             "Chave existe? Permissão de uso?"],
        ],
        col_widths=[Inches(0.8), Inches(3.5), Inches(3.2), Inches(4.2)])
    callout(s, 'warning',
            "Nunca solicitar credenciais do cliente. Para problemas de acesso, "
            "verificar política IAM e orientar o cliente a validar permissões.",
            top=5.2)

    # SLIDE — Referência Rápida do Hotline
    s = content_slide(prs, layouts, "Referência Rápida — Hotline por Família")
    add_table(s,
        ["Família", "Primeira Coisa a Verificar", "Escalar Quando"],
        [
            ["Computação", "Status da VM, quotas, eventos do sistema",
             "Não liga após checagens básicas"],
            ["Armazenamento", "Capacidade, IOPS, anexação do disco",
             "Risco de perda de dados"],
            ["Rede", "VPC, Security Group, EIP, rotas",
             "Perda total de conectividade"],
            ["Banco de Dados", "Slow log, conexões, status HA",
             "Corrupção de dados ou HA failover"],
            ["Segurança", "Política IAM, regras WAF, tráfego",
             "Ataque em andamento ou bloqueio total"],
        ],
        col_widths=[Inches(1.8), Inches(5.5), Inches(4.4)])
    callout(s, 'tip',
            "Esta tabela é o seu guia de bolso. Antes de escalar qualquer SR, "
            "sempre passar pelas verificações da coluna do meio primeiro.",
            top=5.2)

    # SLIDE — Acronimos Principais (sem coluna Full Name)
    s = content_slide(prs, layouts, "Acronimos Principais")
    add_table(s,
        ["Acronimo", "Descrição"],
        [
            ["ECS", "Elastic Cloud Server — servidor virtual escalável"],
            ["EVS", "Elastic Volume Service — disco de bloco elástico"],
            ["VPC", "Virtual Private Cloud — rede virtual isolada"],
            ["ELB", "Elastic Load Balance — balanceador de carga"],
            ["RDS", "Relational Database Service — BD relacional gerenciado"],
            ["OBS", "Object Storage Service — armazenamento de objetos"],
            ["IAM", "Identity & Access Management — gestão de identidade"],
            ["SR", "Service Request — solicitação de serviço (ticket)"],
            ["ITR", "Issue To Resolve — incidente até resolução"],
            ["TAC", "Technical Assistance Center — centro de suporte técnico"],
        ],
        col_widths=[Inches(1.5), Inches(10.2)])

    # SLIDE — Nomenclatura
    s = content_slide(prs, layouts, "Convenção de Nomenclatura")
    text_box(s,
        "Regras para nomes de recursos no HCS:\n\n"
        "  • VMs: [projeto]-[função]-[seq]  (ex: billing-app-01)\n"
        "  • Volumes: [vm]-[disk]-[seq]     (ex: billing-app-disk-01)\n"
        "  • VPCs: [region]-[env]-vpc       (ex: sa-east-1-prod-vpc)\n"
        "  • SRs: SR-[ano][mes][seq]        (ex: SR-202609-00123)\n\n"
        "Validação: sempre confirmar o nome exato do recurso antes de prosseguir.",
        Inches(LEFT_MARGIN), Inches(TOP_CONTENT),
        Inches(CONTENT_WIDTH), Inches(4.5), 14, DARK)

    # ═══════════════════════════════════════════════════════════════
    # CHAPTER 3 — Processo de SR
    # ═══════════════════════════════════════════════════════════════
    chapter_slide(prs, layouts, "Processo de Abertura de SR",
                  "Do email do cliente ao fechamento")

    # SLIDE — Fluxo do SR (flowchart)
    s = content_slide(prs, layouts, "Fluxo do Processo de SR")
    flowchart_vertical(s, [
        {'text': 'Receber SR (email do cliente)', 'fill': GRAY_BG},
        {'type': 'arrow'},
        {'text': 'Validar identidade e contrato', 'fill': GRAY_BG},
        {'type': 'arrow'},
        {'text': 'Classificar severidade (S1-S4)', 'fill': RGBColor(0xFD, 0xF8, 0xEE)},
        {'type': 'arrow'},
        {'text': 'Enviar email para TAC Team', 'fill': RGBColor(0xED, 0xF6, 0xED), 'bold': True},
        {'type': 'arrow'},
        {'text': 'Diagnosticar e resolver', 'fill': GRAY_BG},
        {'type': 'arrow'},
        {'text': 'Verificar e fechar SR', 'fill': GRAY_BG},
    ], left=4.5, top=TOP_CONTENT + 0.1, box_width=4.0, box_height=0.45, gap=0.2)

    # SLIDE — Email para TAC
    s = content_slide(prs, layouts, "Notificação ao TAC Team")
    callout(s, 'warning',
            "OBRIGATÓRIO: ao abrir qualquer SR, enviar email para o TAC Team "
            "usando o template de SR oficial.",
            top=TOP_CONTENT + 0.1)
    text_box(s,
        "Template de SR (campos obrigatórios):\n\n"
        "  • Número do SR\n"
        "  • Cliente e site\n"
        "  • Severidade (S1/S2/S3/S4)\n"
        "  • Serviço afetado (nome oficial)\n"
        "  • Descrição do problema\n"
        "  • Impacto no negócio\n"
        "  • Janela de manutenção (se aplicável)\n"
        "  • Contato do responsável",
        Inches(LEFT_MARGIN), Inches(3.2),
        Inches(CONTENT_WIDTH), Inches(3.5), 13, DARK)

    # SLIDE — Mailbox / Email
    s = content_slide(prs, layouts, "Recebimento de Emails")
    text_box(s,
        "Fluxo atual:\n"
        "  O cliente envia email → hotline recebe e abre SR\n\n"
        "Futuro (em transição):\n"
        "  Emails chegaram via mailbox dedicada → triagem automática\n\n"
        "Independente do canal de entrada, o processo é o mesmo:\n"
        "  1. Validar solicitante\n"
        "  2. Abrir SR no sistema\n"
        "  3. Notificar TAC Team\n"
        "  4. Atribuir responsável",
        Inches(LEFT_MARGIN), Inches(TOP_CONTENT),
        Inches(CONTENT_WIDTH), Inches(4.5), 14, DARK)
    callout(s, 'tip',
            "Sempre validar a identidade do chamador contra a lista de contatos autorizados.",
            top=5.5)

    # ═══════════════════════════════════════════════════════════════
    # CHAPTER 4 — Processo ITR
    # ═══════════════════════════════════════════════════════════════
    chapter_slide(prs, layouts, "Processo ITR (Issue To Resolve)",
                  "Da triagem ao fechamento")

    # SLIDE — Fluxo ITR (flowchart with decisions)
    s = content_slide(prs, layouts, "Fluxo ITR com Escalação")
    # Left column: main flow
    flowchart_vertical(s, [
        {'text': 'Incidente Reportado', 'fill': GRAY_BG},
        {'type': 'arrow'},
        {'text': 'Triagem L1', 'fill': GRAY_BG},
        {'type': 'arrow'},
        {'type': 'decision', 'text': 'L1 resolve?'},
    ], left=1.5, top=TOP_CONTENT + 0.1, box_width=2.5, box_height=0.5, gap=0.25)

    # Right side: escalation path
    flow_box(s, "Escalar para L2", 5.0, 3.3, 2.5, 0.5,
             fill=RGBColor(0xFD, 0xF8, 0xEE), bold=True)
    flow_arrow(s, 4.0, 3.45, 0.5, 0.3, direction='right')

    flowchart_vertical(s, [
        {'type': 'arrow'},
        {'text': 'L2 Investiga', 'fill': GRAY_BG},
        {'type': 'arrow'},
        {'type': 'decision', 'text': 'L2 resolve?'},
    ], left=5.0, top=3.8, box_width=2.5, box_height=0.5, gap=0.25)

    flow_box(s, "Escalar L3/R&D", 8.5, 5.0, 2.5, 0.5,
             fill=RGBColor(0xFD, 0xF8, 0xEE), bold=True)
    flow_arrow(s, 7.5, 5.15, 0.5, 0.3, direction='right')

    # Bottom: resolution path
    flow_box(s, "Resolver & Fechar ITR", 4.5, 6.0, 4.0, 0.5,
             fill=RGBColor(0xED, 0xF6, 0xED), bold=True)

    # SLIDE — Matriz de Escalação
    s = content_slide(prs, layouts, "Matriz de Escalação")
    add_table(s,
        ["Nível", "Responsável", "SLA", "Quando Escalar"],
        [
            ["L1", "Hotline", "15 min", "Problema não identificado"],
            ["L2", "Especialista", "1h", "L1 não resolve em 30 min"],
            ["L3", "Eng. de Produto", "4h", "Bug ou config complexa"],
            ["R&D", "Desenvolvimento", "24h", "Bug de produto confirmado"],
        ])
    callout(s, 'warning',
            "S1 (crítico): escalar imediatamente para L2 ao abrir o SR.",
            top=5.0)

    # �?═══════════════════════════════════════════════════════════════
    # CHAPTER 5 — Operações Comuns
    # ═══════════════════════════════════════════════════════════════
    chapter_slide(prs, layouts, "Operações Comuns de O&M",
                  "Monitoramento, problemas e soluções")

    # SLIDE — Monitoramento
    s = content_slide(prs, layouts, "Monitoramento e Alertas")
    text_box(s,
        "Ferramentas de monitoramento HCS:\n\n"
        "  • ManageOne Operation — dashboards de saúde\n"
        "  • AOM (Application Operations Management) — métricas de app\n"
        "  • APM (Application Performance Monitoring) — traces\n"
        "  • CloudEye — monitoramento de infra\n\n"
        "Alertass comuns:\n"
        "  • CPU > 80% por 5 min → verificar cargas\n"
        "  • Disco > 90% → verificar logs e snapshots\n"
        "  • Memória > 85% → verificar vazamentos\n"
        "  • Latência de rede > 100ms → verificar VPC/ELB",
        Inches(LEFT_MARGIN), Inches(TOP_CONTENT),
        Inches(CONTENT_WIDTH), Inches(4.5), 13, DARK)

    # SLIDE — Problemas Comuns
    s = content_slide(prs, layouts, "Problemas Comuns e Soluções Rápidas")
    add_table(s,
        ["Problema", "Sintoma", "Ação Rápida"],
        [
            ["VM não liga", "Status: ERROR", "Verificar quotas, disco, rede"],
            ["Disco cheio", "Alerta > 90%", "Limpar logs, expandir EVS"],
            ["Sem rede", "Ping falha", "Verificar VPC, EIP, SG"],
            ["ELB unhealthy", "Backend down", "Verificar health check, porta"],
            ["RDS lento", "Query timeout", "Verificar slow log, índices"],
            ["OBS 403", "Access denied", "Verificar AK/SK, policy IAM"],
        ])

    # ═══════════════════════════════════════════════════════════════
    # CHAPTER 6 — Melhores Práticas
    # ═══════════════════════════════════════════════════════════════
    chapter_slide(prs, layouts, "Melhores Práticas",
                  "Checklist e recursos")

    # SLIDE — Do's and Don'ts
    s = content_slide(prs, layouts, "O Que Fazer e O Que Não Fazer")
    callout(s, 'warning',
            "Nunca solicitar ou aceitar credenciais do cliente. "
            "Oriente ao autoatendimento.",
            top=TOP_CONTENT + 0.1)
    callout(s, 'tip',
            "Sempre confirmar o nome exato do serviço e recurso antes de prosseguir.",
            top=TOP_CONTENT + 1.0)
    callout(s, 'infobox',
            "Documentar cada passo do troubleshooting no SR para rastreabilidade.",
            top=TOP_CONTENT + 1.9)
    callout(s, 'warning',
            "Não aplicar workaround em produção sem janela de manutenção aprovada.",
            top=TOP_CONTENT + 2.8)
    callout(s, 'tip',
            "Usar o template de SR oficial ao notificar o TAC Team.",
            top=TOP_CONTENT + 3.7)

    # SLIDE — Recursos de Autoatendimento
    s = content_slide(prs, layouts, "Recursos de Autoatendimento")
    text_box(s,
        "Direcionar clientes para:\n\n"
        "  • ServiceCenter — portal de autoserviço\n"
        "  • Documentação HCS — docs.huaweicloud.com\n"
        "  • Knowledge Base — artigos de troubleshooting\n"
        "  • Status Page — status dos serviços\n"
        "  • Forum — comunidade técnica\n\n"
        "Benefícios:\n"
        "  • Reduz volume de SRs de baixa severidade\n"
        "  • Cliente resolve mais rápido\n"
        "  • Hotline foca em S1/S2",
        Inches(LEFT_MARGIN), Inches(TOP_CONTENT),
        Inches(CONTENT_WIDTH), Inches(4.5), 14, DARK)

    # SLIDE — Checklist de Validação
    s = content_slide(prs, layouts, "Checklist de Validação do SR")
    text_box(s,
        "Antes de fechar qualquer SR, validar:\n\n"
        "  [ ] Identidade do solicitante confirmada\n"
        "  [ ] Nome oficial do serviço identificado\n"
        "  [ ] Severidade classificada corretamente\n"
        "  [ ] TAC Team notificado com template\n"
        "  [ ] Diagnóstico documentado no SR\n"
        "  [ ] Solução aplicada e verificada\n"
        "  [ ] Cliente confirmou a resolução\n"
        "  [ ] SR fechado com resolução documentada\n"
        "  [ ] Lições aprendidas registradas (se aplicável)",
        Inches(LEFT_MARGIN), Inches(TOP_CONTENT),
        Inches(CONTENT_WIDTH), Inches(4.5), 14, DARK)

    # SLIDE — Objetivo: 01/09
    s = content_slide(prs, layouts, "Próximos Passos")
    text_box(s,
        "Objetivo: equipe autorando conteúdo a partir de 01/09\n\n"
        "Preparação necessária:\n"
        "  1. Revisar este treinamento completo\n"
        "  2. Praticar abertura de SRs com template\n"
        "  3. Familiarizar com ManageOne e ServiceCenter\n"
        "  4. Estudar fluxos ITR e matriz de escalação\n"
        "  5. Conhecer acronimos e famílias de serviços\n\n"
        "Stack alvo: HCS 8.6.1",
        Inches(LEFT_MARGIN), Inches(TOP_CONTENT),
        Inches(CONTENT_WIDTH), Inches(4.5), 14, DARK)
    callout(s, 'tip',
            "Dúvidas? Consultar a matriz de escalação ou escalar para L2.",
            top=5.8)

    # ═══════════════════════════════════════════════════════════════
    # LAST SLIDE
    # ═══════════════════════════════════════════════════════════════
    last_slide(prs, layouts)

    path = save_deck(prs, os.path.join(OUT_DIR, "sample-pt-br.pptx"))
    print(f"Saved: {path}")


if __name__ == "__main__":
    main()
