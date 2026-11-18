# Automação e Provisionamento de Imagens: Cloud-init & HashiCorp Packer

> **Disciplina:** Computação em Nuvem e Infraestrutura Ágil (FAPDEVOPS)  
> **Ferramentas:** HashiCorp Packer v1.11.2 • Docker Engine • Ubuntu 22.04 LTS (`ubuntu:jammy`)  
> **Relatório Visual Completo (HTML/PDF):** [`RELATORIO_FINAL_PACKER.html`](./RELATORIO_FINAL_PACKER.html)

---

## Parte I — Questões Conceituais (Cloud-init & Packer)

### 1. O que é o Cloud-init?
- **Conceito & Propósito:** O **Cloud-init** é o padrão multiplataforma da indústria para inicialização e configuração automatizada de instâncias em nuvem durante o **primeiro boot** (*Zero-Touch Provisioning*). Ele atua como um agente instalado na imagem base do sistema operacional que lê metadados e scripts declarativos (`user-data` em YAML ou Shell) fornecidos pelo provedor de nuvem (AWS, Azure, GCP, OpenStack) assim que a máquina virtual liga pela primeira vez.
- **Exemplo Prático na Nuvem:** Ao lançar uma instância **Amazon EC2** via Terraform ou console AWS, fornecemos um script `#cloud-config` no campo `user-data` que automaticamente cria o usuário da equipe de DevOps com permissão `sudo`, injeta as chaves públicas SSH autorizadas, monta um volume de dados adicional e registra a máquina em um *Target Group* ou agente de observabilidade antes mesmo do primeiro acesso humano.

---

### 2. O que é o HashiCorp Packer?
- **Conceito & Funcionamento:** O **HashiCorp Packer** é uma ferramenta open-source de Infraestrutura como Código (IaC) que automatiza a criação de imagens de máquina idênticas e imutáveis (*Golden Images* ou imagens de contêiner) a partir de um único arquivo de configuração declarativo em HCL (`.pkr.hcl`). O Packer inicia um ambiente temporário (*Builder*), executa comandos e copia arquivos para instalar dependências (*Provisioners*), congela o estado gerando a imagem final e aplica tags/versões (*Post-Processors*), removendo o contêiner ou VM provisória ao final.
- **Problema Real que Resolve em uma Empresa:** Em cenários de alta demanda (como um e-commerce em Black Friday), se o grupo de *Auto Scaling* tentar provisionar 30 novas máquinas instalando pacotes pesados (`apt`, `pip`, `npm`, servidores web e agentes de segurança) do zero durante o boot, cada servidor levará de **12 a 20 minutos** para ficar disponível — além do risco de falha caso algum repositório externo oscile. O Packer resolve essa dor aplicando o conceito de **Baking**: a imagem já é "assada" e validada previamente na esteira de CI/CD com todo o stack embutido, permitindo que novos servidores subam em produção em **menos de 15 segundos** com 100% de padronização.

---

### 3. Análise Comparativa: Packer (*Golden Image*) vs. Cloud-init

| Critério Técnico | HashiCorp Packer (*Baking / Golden Image*) | Cloud-init (*Bootstrapping / First Boot*) |
| :--- | :--- | :--- |
| **Momento de Ação** | **Build Time (Pré-Deploy):** Executado antes do deploy para gerar o molde da imagem. | **Run Time (Primeiro Boot):** Executado quando a instância virtual liga pela primeira vez. |
| **Objetivo Principal** | Empacotar o sistema operacional, runtimes, servidores e dependências pesadas em uma imagem imutável e testada. | Aplicar configurações dinâmicas e específicas daquela instância viva (hostname, IP, chaves SSH, variáveis de ambiente). |
| **Tempo de Subida** | **Ultrarrápido (segundos):** Tudo já está pré-instalado no disco da imagem. | **Mais lento (minutos)** se for usado para baixar e compilar pacotes via rede a cada boot. |
| **Sinergia no Mercado** | **Atuam de forma complementar:** O **Packer** prepara a *Golden Image* corporativa com 95% das dependências estáticas pré-instaladas, e o **Cloud-init** realiza apenas o ajuste fino final (identidade e registro no cluster) quando a máquina liga. |

---

## Parte II — Laboratórios Práticos (HashiCorp Packer & Docker)

### Estrutura do Repositório

```text
atividade Packer/
├── desafio1/
│   ├── desafio1.pkr.hcl          # Receita HCL: Ubuntu + Apache2 + injeção de index.html
│   ├── index.html                # Página web local injetada via provisioner "file"
│   ├── build.log                 # Log completo do packer build
│   └── validacao_desafio1.txt    # Saída do teste HTTP na porta 8081
├── desafio2/
│   ├── desafio2.pkr.hcl          # Receita HCL: Ubuntu + Python3/Pip + Flask + WORKDIR /app
│   ├── build.log                 # Log completo do packer build
│   └── validacao_desafio2.txt    # Saída do teste python3 -m flask --version
├── desafio3/
│   ├── desafio3.pkr.hcl          # Receita HCL: Ubuntu + Node.js/NPM + package.json + npm install
│   ├── package.json              # Manifesto JSON local copiado para /app/package.json
│   ├── build.log                 # Log completo do packer build
│   └── validacao_desafio3.txt    # Saída dos testes de versão e listagem de /app
├── RELATORIO_FINAL_PACKER.html   # Relatório completo estilizado (pronto para exportar em PDF)
└── README.md                     # Documentação consolidada da entrega
```

---

### Atividade 1: Servidor Web Apache com Ficheiros Locais (`meu-apache-packer:latest`)
- **Arquivo:** [`desafio1/desafio1.pkr.hcl`](./desafio1/desafio1.pkr.hcl)
- **Evidência de Validação:** [`desafio1/validacao_desafio1.txt`](./desafio1/validacao_desafio1.txt)

```text
--> meu-apache.docker.ubuntu: Imported Docker image: meu-apache-packer:latest with tags meu-apache-packer:latest

$ docker run -d -p 8081:80 --name test-apache meu-apache-packer:latest
ed5e4689ae1f82d09e9e52cfdf2f232942bb897f82083b418b5daa3e9003d30b

$ curl.exe -i -s http://localhost:8081
HTTP/1.1 200 OK
Server: Apache/2.4.52 (Ubuntu)
Content-Length: 2759
Content-Type: text/html
```

---

### Atividade 2: Ambiente Base para Python + Flask (`ambiente-dev-python:v1`)
- **Arquivo:** [`desafio2/desafio2.pkr.hcl`](./desafio2/desafio2.pkr.hcl)
- **Evidência de Validação:** [`desafio2/validacao_desafio2.txt`](./desafio2/validacao_desafio2.txt)

```text
--> dev-python.docker.python_base: Imported Docker image: sha256:86d13d7dab4a442c11d0989aa328fc1c19e7f5f49d0b2eafcf6d407e4fc1aa5b
--> dev-python.docker.python_base: Imported Docker image: ambiente-dev-python:v1 with tags ambiente-dev-python:v1

$ docker run --rm ambiente-dev-python:v1 python3 -m flask --version
Python 3.10.12
Flask 3.1.3
Werkzeug 3.1.9

$ docker run --rm ambiente-dev-python:v1 pwd
/app
```

---

### Atividade 3: Ambiente Node.js em Múltiplos Passos (`ambiente-node:v1`)
- **Arquivo:** [`desafio3/desafio3.pkr.hcl`](./desafio3/desafio3.pkr.hcl)
- **Evidência de Validação:** [`desafio3/validacao_desafio3.txt`](./desafio3/validacao_desafio3.txt)

```text
==> dev-node.docker.node_base: Uploading package.json => /app/package.json
==> dev-node.docker.node_base: Provisioning with shell script
    dev-node.docker.node_base: up to date, audited 1 package in 6s
    dev-node.docker.node_base: found 0 vulnerabilities
--> dev-node.docker.node_base: Imported Docker image: ambiente-node:v1 with tags ambiente-node:v1

$ docker run --rm ambiente-node:v1 node -v
v12.22.9

$ docker run --rm ambiente-node:v1 npm -v
8.5.1

$ docker run --rm ambiente-node:v1 ls -la /app
-rw-r--r-- 1 root root   82 Nov 18 00:44 package-lock.json
-rw-rw-rw- 1 root root    3 Oct 28 14:43 package.json
```
