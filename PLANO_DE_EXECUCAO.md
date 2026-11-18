# Guia de Execução Rápida: Atividade Cloud-init & HashiCorp Packer

> **Disciplina:** Computação em Nuvem e Infraestrutura Ágil / FAPDEVOPS  
> **Status do Ambiente:** Packer v1.11.2 instalado no PATH • Docker ativo e respondendo  
> **Objetivo:** Roteiro prático e conceitual para execução imediata da atividade ao retornar.

---

## 1. O que a Atividade Exige (Mapeamento Completo)

A entrega final é composta por duas partes integradas:

1. **Parte Teórica (3 Questões Conceituais):**
   - O que é o *Cloud-init* (conceito, propósito e caso real na nuvem).
   - O que é o *Packer* (conceito, funcionamento e dor de mercado que resolve).
   - Análise comparativa: *Baking* (Packer / Golden Image) vs. *Bootstrapping* (Cloud-init no primeiro boot).
2. **Parte Prática (3 Laboratórios Hands-on com Packer + Docker):**
   - **Desafio 1 (Iniciante):** Imagem Apache (`meu-apache-packer`) com arquivo local `index.html` injetado via provisioner `file`.
   - **Desafio 2 (Intermediário):** Imagem Python (`ambiente-dev-python:v1`) com pasta `/app`, biblioteca `Flask` via pip e validação da versão.
   - **Desafio 3 (Múltiplos Passos):** Imagem Node.js (`ambiente-node:v1`) com injeção do `package.json` local e execução do `npm install` no `/app`.

---

## 2. Respostas das Questões Teóricas (Prontas para o Relatório)

### Questão 1: O que é o Cloud-init?
- **Conceito & Propósito:** O Cloud-init é o padrão multiplataforma da indústria para inicialização e configuração de instâncias no primeiro boot (*Zero-Touch Provisioning*). Ele atua como um agente que interpreta metadados e scripts declarativos (`user-data`) fornecidos pelo provedor de nuvem para preparar a máquina virtual antes do primeiro login humano.
- **Exemplo Prático na Nuvem:** Ao lançar uma instância EC2 na AWS via console ou Terraform, passamos um script YAML que cria automaticamente o usuário do desenvolvedor, injeta chaves públicas SSH, instala o Nginx e adiciona a máquina ao pool de um Application Load Balancer sem que ninguém precise abrir uma sessão SSH.

---

### Questão 2: O que é o HashiCorp Packer?
- **Conceito & Funcionamento:** O Packer é uma ferramenta open-source de Infraestrutura como Código (IaC) criada para automatizar a geração de imagens de máquinas idênticas (*Golden Images* ou imagens de containers) para múltiplas plataformas (Docker, AWS AMI, Azure VHD, Google Compute, VMware) a partir de um único arquivo de configuração HCL (`.pkr.hcl`).
- **Problema Real que Resolve:** Em grandes empresas, criar instâncias do zero instalando dezenas de dependências em tempo de execução (*boot*) é lento (leva 15 a 20 minutos por máquina), suscetível a indisponibilidades externas (falha no repositório `apt` ou `npm`) e quebra esteiras de Auto Scaling. O Packer resolve isso aplicando o conceito de **Baking**: o servidor já é "assado" previamente com todas as dependências pré-instaladas, subindo em produção em menos de 10 segundos.

---

### Questão 3: Análise Comparativa (Packer vs. Cloud-init)

| Critério | HashiCorp Packer (*Baking*) | Cloud-init (*Bootstrapping / Frying*) |
| :--- | :--- | :--- |
| **Momento de Ação** | **Build Time:** Executado antes do deploy, na esteira de CI/CD, para gerar o molde da imagem. | **Run Time:** Executado no momento em que a instância virtual liga pela primeira vez. |
| **Objetivo Principal** | Criar a *Golden Image* estática, imutável, segura e homologada com todas as dependências pré-instaladas. | Customizar dinamicamente a instância no primeiro boot (hostname, IP estático, certificados únicos, chaves SSH). |
| **Tempo de Subida** | Ultrarrápido (segundos), pois nada precisa ser baixado ou compilado na partida. | Mais lento (minutos), dependendo da quantidade de pacotes a instalar via rede. |
| **Sinergia no Mercado** | **Usados juntos:** O Packer cria a imagem base corporativa pesada, e o Cloud-init apenas aplica o ajuste fino individual da máquina ao ligar. |

---

## 3. Roteiro dos 3 Desafios Práticos (Estrutura e Comandos)

### 3.1. Estrutura de Pastas Recomendada
```text
atividade Packer/
├── desafio1/
│   ├── desafio1.pkr.hcl
│   └── index.html
├── desafio2/
│   └── desafio2.pkr.hcl
├── desafio3/
│   ├── desafio3.pkr.hcl
│   └── package.json
└── PLANO_DE_EXECUCAO.md
```

---

### 3.2. Desafio 1: Servidor Web Apache com Arquivo Local

- **Arquivo `desafio1.pkr.hcl`:**
```hcl
packer {
  required_plugins {
    docker = {
      version = ">= 1.0.8"
      source  = "github.com/hashicorp/docker"
    }
  }
}

source "docker" "ubuntu" {
  image  = "ubuntu:jammy"
  commit = true
  changes = [
    "EXPOSE 80",
    "CMD [\"apachectl\", \"-D\", \"FOREGROUND\"]"
  ]
}

build {
  name    = "meu-apache"
  sources = ["source.docker.ubuntu"]

  # 1. Instalação do Apache
  provisioner "shell" {
    inline = [
      "apt-get update",
      "DEBIAN_FRONTEND=noninteractive apt-get install -y apache2",
      "apt-get clean"
    ]
  }

  # 2. Injeção do index.html local
  provisioner "file" {
    source      = "index.html"
    destination = "/var/www/html/index.html"
  }

  # 3. Nomeação final
  post-processor "docker-tag" {
    repository = "meu-apache-packer"
    tags       = ["latest"]
  }
}
```

- **Comandos de Execução e Teste:**
  ```powershell
  packer init .
  packer validate .
  packer build .
  docker run -d -p 8081:80 --name test-apache meu-apache-packer:latest
  curl http://localhost:8081
  ```

---

### 3.3. Desafio 2: Ambiente Python + Flask

- **Arquivo `desafio2.pkr.hcl`:**
```hcl
packer {
  required_plugins {
    docker = {
      version = ">= 1.0.8"
      source  = "github.com/hashicorp/docker"
    }
  }
}

source "docker" "python_base" {
  image  = "ubuntu:jammy"
  commit = true
  changes = [
    "WORKDIR /app"
  ]
}

build {
  name    = "dev-python"
  sources = ["source.docker.python_base"]

  provisioner "shell" {
    inline = [
      "apt-get update",
      "DEBIAN_FRONTEND=noninteractive apt-get install -y python3 python3-pip",
      "mkdir -p /app",
      "pip install --no-cache-dir Flask"
    ]
  }

  post-processor "docker-tag" {
    repository = "ambiente-dev-python"
    tags       = ["v1"]
  }
}
```

- **Comandos de Execução e Validação do PDF:**
  ```powershell
  packer init .
  packer build .
  docker run -it --rm ambiente-dev-python:v1 python3 -m flask --version
  ```

---

### 3.4. Desafio 3: Ambiente Node.js (Múltiplos Passos)

- **Arquivo `desafio3.pkr.hcl`:**
```hcl
packer {
  required_plugins {
    docker = {
      version = ">= 1.0.8"
      source  = "github.com/hashicorp/docker"
    }
  }
}

source "docker" "node_base" {
  image  = "ubuntu:jammy"
  commit = true
}

build {
  name    = "dev-node"
  sources = ["source.docker.node_base"]

  # Passo 1: Instalação do Node.js e NPM
  provisioner "shell" {
    inline = [
      "apt-get update",
      "DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs npm",
      "mkdir -p /app"
    ]
  }

  # Passo 2: Cópia do package.json local
  provisioner "file" {
    source      = "package.json"
    destination = "/app/package.json"
  }

  # Passo 3: Execução do npm install
  provisioner "shell" {
    inline = [
      "cd /app && npm install"
    ]
  }

  # Passo 4: Tag final da imagem
  post-processor "docker-tag" {
    repository = "ambiente-node"
    tags       = ["v1"]
  }
}
```

- **Comandos de Execução e Teste:**
  ```powershell
  packer init .
  packer build .
  docker run -it --rm ambiente-node:v1 node -v
  docker run -it --rm ambiente-node:v1 npm -v
  ```

---

## 4. Próximos Passos Imediatos ao Retornar

1. Criar as subpastas e arquivos locais (`index.html` e `package.json`).
2. Disparar os builds em sequência.
3. Coletar os 3 prints dos terminais comprovando as validações.
4. Gerar o relatório final consolidado (HTML + Markdown).
