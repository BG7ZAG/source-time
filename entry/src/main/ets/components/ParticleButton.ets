@Component
export struct ParticleButton {
  @State particleActive: boolean = false;
  @Prop text: string = '';
  @Prop buttonType: ButtonType = ButtonType.Circle;
  @Prop buttonWidth: number = 56;
  @Prop buttonHeight: number = 56;
  @Prop fontSize: number = 24;
  @Prop bgColor: ResourceColor = $r('app.color.brand');
  @Prop fontColor: ResourceColor = $r('app.color.fab_foreground');
  onTap: () => void = () => {};

  private particleTimerId: number = -1;

  aboutToDisappear(): void {
    if (this.particleTimerId >= 0) {
      clearTimeout(this.particleTimerId);
      this.particleTimerId = -1;
    }
  }

  private triggerParticle(): void {
    this.particleActive = true;
    if (this.particleTimerId >= 0) {
      clearTimeout(this.particleTimerId);
    }
    this.particleTimerId = setTimeout(() => {
      this.particleActive = false;
      this.particleTimerId = -1;
    }, 1000);
  }

  build() {
    Stack() {
      Button(this.text)
        .type(this.buttonType)
        .width(this.buttonWidth)
        .height(this.buttonHeight)
        .fontSize(this.fontSize)
        .backgroundColor(this.bgColor)
        .fontColor(this.fontColor)
        .shadow({ radius: 8, color: '#33000000', offsetX: 0, offsetY: 2 })
        .onClick(() => {
          this.triggerParticle();
          this.onTap();
        })

      if (this.particleActive) {
        Particle({
          particles: [{
            emitter: {
              particle: {
                type: ParticleType.POINT,
                config: { radius: 2 },
                count: 16,
                lifetime: 1000
              },
              shape: ParticleEmitterShape.CIRCLE,
              position: [this.buttonWidth / 2, this.buttonHeight / 2],
              size: [2, 2]
            },
            velocity: {
              angle: [0, 360],
              speed: [80, 140]
            },
            acceleration: {
              angle: { range: [90, 90] },
              speed: { range: [20, 40] }
            },
            color: { range: ['#3D7DF7', '#6ED0FF'] },
            opacity: { range: [0.6, 1.0] },
            scale: { range: [0.2, 0.6] }
          }]
        })
        .width(this.buttonWidth)
        .height(this.buttonHeight)
        .hitTestBehavior(HitTestMode.Transparent)
      }
    }
    .width(this.buttonWidth)
    .height(this.buttonHeight)
    .clip(false)
  }
}
