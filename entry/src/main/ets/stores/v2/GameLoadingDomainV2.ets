@ObservedV2
export class GameLoadingDomainV2 {
  @Trace isLoading: boolean = false
  @Trace title: string = ''
  @Trace message: string = ''
  @Trace progress: number = 0

  begin(title: string, message: string, progress: number = 0): void {
    this.isLoading = true
    this.title = title
    this.message = message
    this.progress = progress
  }

  update(message: string, progress?: number): void {
    this.message = message
    if (progress !== undefined) {
      this.progress = progress
    }
  }

  finish(): void {
    this.isLoading = false
    this.progress = 100
  }
}
