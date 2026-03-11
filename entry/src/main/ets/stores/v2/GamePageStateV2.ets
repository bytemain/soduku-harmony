import { GameHistoryDomainV2 } from './GameHistoryDomainV2'
import { GameInteractionDomainV2 } from './GameInteractionDomainV2'
import { GameLoadingDomainV2 } from './GameLoadingDomainV2'
import { GameRuntimeContext } from './GameRuntimeContext'
import { GameSessionDomainV2 } from './GameSessionDomainV2'
import { GameUiDomainV2 } from './GameUiDomainV2'

@ObservedV2
export class GamePageStateV2 {
  @Trace session: GameSessionDomainV2 = new GameSessionDomainV2()
  @Trace ui: GameUiDomainV2 = new GameUiDomainV2()
  @Trace loading: GameLoadingDomainV2 = new GameLoadingDomainV2()
  @Trace interaction: GameInteractionDomainV2 = new GameInteractionDomainV2()
  @Trace history: GameHistoryDomainV2 = new GameHistoryDomainV2()

  runtime: GameRuntimeContext = new GameRuntimeContext()
}
