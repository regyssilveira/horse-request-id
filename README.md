# Horse Request ID

Middleware de geração e rastreamento de Request ID (Correlation ID) para o ecossistema do framework [Horse](https://github.com/HashLoad/horse).

Este middleware garante que toda requisição processada pelo servidor possua um identificador único de rastreabilidade (UUID/GUID), facilitando a depuração e correlação de logs em ambientes de microsserviços e sistemas distribuídos.

---

## ⚙️ Instalação

A instalação é feita de forma simples através do gerenciador de pacotes [`boss`](https://github.com/HashLoad/boss):

```sh
boss install horse-request-id
```

---

## ⚡ Como usar

### 1. Configuração Básica
Basta registrar o middleware no pipeline do Horse. Por padrão, ele utilizará o cabeçalho `X-Request-ID` tanto para ler requisições existentes quanto para injetar na resposta enviada ao cliente.

```delphi
program Console;

{$APPTYPE CONSOLE}

uses
  Horse,
  Horse.RequestID;

begin
  // Registra o middleware com as configurações padrão
  THorse.Use(RequestID);

  THorse.Get('/ping',
    procedure(Req: THorseRequest; Res: THorseResponse)
    begin
      Res.Send('pong');
    end);

  THorse.Listen(9000);
end.
```

### 2. Recuperando o Request ID em seus Controllers
Para acessar o Request ID gerado (ou recebido) dentro dos seus endpoints, utilize o método estático `THorseRequestID.Get(Req)`:

```delphi
THorse.Get('/dados',
  procedure(Req: THorseRequest; Res: THorseResponse)
  var
    LRequestID: string;
  begin
    // Recupera o ID único da requisição ativa
    LRequestID := THorseRequestID.Get(Req);
    
    // Pode ser enviado no corpo da resposta ou persistido em logs / banco de dados
    Res.Send(Format('{"mensagem": "Processado com sucesso", "correlation_id": "%s"}', [LRequestID]));
  end);
```

### 3. Configuração Avançada (Cabeçalho Customizado)
Você pode personalizar o nome do cabeçalho HTTP de retorno definindo uma string na inicialização ou através do registro de configuração `THorseRequestIDConfig`.

#### Definindo o cabeçalho como string:
```delphi
// O middleware passará a ler e retornar no cabeçalho "X-Correlation-ID"
THorse.Use(RequestID('X-Correlation-ID'));
```

#### Definindo via Registro de Configurações:
```delphi
var
  LConfig: THorseRequestIDConfig;
begin
  LConfig.HeaderName := 'X-My-Correlation-ID';
  THorse.Use(RequestID(LConfig));
end;
```

---

## 🔄 Funcionamento Detalhado do Fluxo
1. **Verificação de Cabeçalhos de Entrada:** O middleware examina a requisição em busca dos seguintes cabeçalhos (nesta ordem de prioridade):
   - Cabeçalho personalizado configurado (ex: `X-Correlation-ID`).
   - `X-Request-ID`.
   - `X-Correlation-ID`.
2. **Geração do ID:** Se nenhum cabeçalho de ID for enviado pelo cliente, o middleware gera um GUID novo de forma thread-safe, removendo as chaves `{` e `}` para formatação limpa.
3. **Injeção de Escopo (`Req.Services`):** O ID gerado/recebido é injetado no container IoC da requisição (`Req.Services`) sob a classe `THorseRequestID`. O ciclo de vida desse objeto é gerenciado de forma nativa e automática pelo Horse, evitando *memory leaks*.
4. **Header de Resposta:** O ID é injetado nos headers de resposta no mesmo cabeçalho configurado, permitindo que o cliente saiba qual foi o ID que processou sua transação.

---

## 💻 Compatibilidade
* **Delphi XE7** ou superior.
* **Lazarus / Free Pascal (FPC 3.2+)**.
* Compatível com todos os providers de transporte do Horse (Indy, CrossSocket, mORMot2, etc.).
* Desenvolvido sob princípios **Clean Code**, **SOLID** e thread-safe.

---

## 📄 Licença
Este projeto está licenciado sob a [Licença MIT](LICENSE).
