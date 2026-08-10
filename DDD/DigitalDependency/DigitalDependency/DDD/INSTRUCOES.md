# Camada 1 — Integração no Xcode

## Ordem de execução

Faça nesta ordem. Cada passo é testável isoladamente; não pule para o
próximo antes do anterior compilar.

### 1. Estrutura de pastas (5 min)

No Xcode, crie os grupos e arraste os arquivos:

```
DigitalDependency/
├── DigitalDependencyApp.swift
├── Models/DomainModels.swift
├── DataSources/
│   ├── UsageDataSource.swift
│   ├── SimulatedUsageDataSource.swift
│   └── ScreenTimeUsageDataSource.swift
├── Core/
│   ├── SessionBuilder.swift
│   ├── FeatureEngineer.swift
│   ├── MLModelManager.swift
│   └── AssessmentCoordinator.swift
├── Persistence/
│   ├── PersistenceController.swift
│   └── AssessmentStore.swift
├── Services/NotificationService.swift
└── Views/
    ├── DashboardView.swift
    ├── HistoryView.swift
    └── SettingsView.swift
```

Ao arrastar, marque **Copy items if needed** e confirme que o target está
selecionado. Arquivo fora do target compila sem erro e some em runtime —
é o erro mais comum e o mais difícil de perceber.

### 2. Remover o ContentView antigo (2 min)

O `ContentView.swift` original vira redundante: `DashboardView` ocupa o
lugar dele. Delete ou renomeie para `LegacyShowcaseView.swift` se quiser
manter o mostruário de 3 cenários para comparação na apresentação.

Se mantiver, remova o `@main` antigo — só pode existir um ponto de entrada.

### 3. Confirmar o modelo CoreML (5 min)

O `RiskClassifier.mlmodel` precisa estar no target. Verifique:

- Selecione o `.mlmodel` no navegador
- Painel direito → **Target Membership** → app marcado
- Clique na aba do modelo e confira os nomes das entradas

**Ponto crítico:** os 13 nomes em `MLModelManager` devem bater exatamente
com os do modelo. Se o Xcode gerar tipos diferentes de `NSNumber`
(por exemplo `Double` direto), ajuste a chamada — o compilador avisa.

Se `output.risk_level` não for `Int64`, adapte o cast em `MLModelManager`.

### 4. Primeira compilação (10 min)

Rode no simulador. Esperado:

- Abre no dashboard, banner "Dados simulados"
- Botão "Gerar avaliação" produz um resultado
- Aba Histórico mostra o registro
- Fecha e reabre: o histórico permanece

Se o histórico sumir ao reabrir, o CoreData não persistiu — verifique se
`PersistenceController.shared` está sendo usado em todos os pontos.

### 5. Validar os três perfis (10 min)

Em Ajustes, alterne entre Equilibrado / Moderado / Compulsivo e gere uma
avaliação de cada. Esperado: LOW, MEDIUM e HIGH respectivamente.

**Se não bater, não force os dados.** Significa que as features calculadas
em Swift divergem das do Python. Me mande os valores que aparecem no painel
"Features calculadas" e eu comparo com a distribuição do dataset.

### 6. Notificações (5 min)

Em Ajustes, ative o lembrete diário. O iOS pedirá permissão. Gere uma
avaliação MEDIUM ou HIGH — a notificação chega em 2 segundos.

Notificações não aparecem se o app estiver em primeiro plano sem
`UNUserNotificationCenterDelegate`. Para a demonstração, mande o app para
segundo plano logo após gerar.

---

## Camada 2 — quando a Apple aprovar

1. Target → Signing & Capabilities → **+ Capability** → Family Controls
2. Criar App Group em ambos os targets e atualizar `ThresholdEventStore.appGroupID`
3. File → New → Target → **Device Activity Monitor Extension**
4. Na extension, sobrescrever `eventDidReachThreshold` chamando
   `ThresholdEventStore.shared.record(...)`
5. Em Ajustes, tocar em "Usar dados do dispositivo"

Nada disso exige mexer no pipeline: a troca acontece via `setDataSource`.

**Só funciona em dispositivo físico.** Thresholds não disparam no simulador.

---

## Pontos declaráveis na monografia

Três decisões desta camada precisam aparecer no texto:

1. **Segmentação de sessão** (`SessionBuilder.inactivityThreshold`, 5 min).
   O LSApp trazia `session_id` pronto; no iOS a sessão é inferida. Este
   parâmetro não existia no treino.

2. **Estimativa por limiares** (`ThresholdEventStore.events`). Os eventos
   derivados da Screen Time são reconstruções a partir de marcos de
   threshold, não observações diretas.

3. **Origem dos rótulos.** Os rótulos de treino foram gerados pela regra
   de limiares reproduzida em `RuleBasedClassifier`. O modelo aprende a
   aproximar essa regra. Declarar isso como limitação é mais defensável
   do que apresentar a acurácia sem contexto.

Os três estão comentados no próprio código, com referência ao script
Python correspondente.
