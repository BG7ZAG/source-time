@Component
export struct EmptyState {
  @Prop message: string = '暂无验证码';

  build() {
    Column({ space: 12 }) {
      Stack() {
        Particle({
          particles: [{
            emitter: {
              particle: {
                type: ParticleType.POINT,
                config: { radius: 2 },
                count: 12,
                lifetime: 3000
              },
              shape: ParticleEmitterShape.CIRCLE,
              position: [50, 50],
              size: [2, 2]
            },
            velocity: {
              angle: [0, 360],
              speed: [10, 30]
            },
            acceleration: {
              angle: { range: [270, 270] },
              speed: { range: [5, 10] }
            },
            color: { range: ['#3D7DF7', '#6ED0FF'] },
            opacity: { range: [0.3, 0.7] },
            scale: { range: [0.1, 0.3] }
          }]
        })
        .width(100)
        .height(100)
        .hitTestBehavior(HitTestMode.Transparent)

        Text('＋')
          .fontSize(40)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.brand'))
      }
      .width(100)
      .height(100)
      .clip(false)

      Text(this.message)
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
    }
    .justifyContent(FlexAlign.Center)
  }
}
