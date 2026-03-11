@ObservedV2
export class GameUiDomainV2 {
  @Trace showSettings: boolean = false
  @Trace showPauseOverlay: boolean = false
  @Trace showGestureGuide: boolean = false
  @Trace showCoordinates: boolean = false
  @Trace showAutoNotes: boolean = false
  @Trace boardScale: number = 0.92
  @Trace boardOpacity: number = 0
  @Trace completionScale: number = 1
  @Trace numPadHeight: number = 0

  syncPreferences(showCoordinates: boolean, showAutoNotes: boolean): void {
    this.showCoordinates = showCoordinates
    this.showAutoNotes = showAutoNotes
  }

  openSettings(): void {
    this.showSettings = true
  }

  closeSettings(): void {
    this.showSettings = false
  }

  showPause(): void {
    this.showPauseOverlay = true
  }

  hidePause(): void {
    this.showPauseOverlay = false
  }

  showGuide(): void {
    this.showGestureGuide = true
  }

  hideGuide(): void {
    this.showGestureGuide = false
  }

  setBoardVisible(scale: number = 1, opacity: number = 1): void {
    this.boardScale = scale
    this.boardOpacity = opacity
  }

  setCompletionScale(scale: number): void {
    this.completionScale = scale
  }

  setNumPadHeight(height: number): void {
    this.numPadHeight = height
  }

  resetTransientUi(): void {
    this.showSettings = false
    this.showPauseOverlay = false
    this.showGestureGuide = false
    this.boardScale = 0.92
    this.boardOpacity = 0
    this.completionScale = 1
  }
}
