const ease = (value: number) => { const t=Math.max(0,Math.min(1,value)); return t*t*(3-2*t) }
const pulse = (value: number) => Math.sin(Math.PI*ease(value))**2
/** Gaze, small head gestures and asymmetric ear flicks share one character pose. */
export function dictationFoxPose(time: number, level: number, still: boolean) {
  const mood = (['neutral','curious','happy','wink','love'] as const)[Math.floor(time/7.8)%5]
  if (still) return {mood,blink:false,x:0,y:0,tilt:0,scale:1,leftEar:-24,rightEar:24}
  const local=time%3.7, gesture=pulse(local/1.8), nod=Math.sin(local*8)*gesture
  const x=Math.sin(time*.85)*1.2+Math.sin(time*1.9)*.3
  const y=Math.sin(time*2.4)*.3+(mood==='happy'?nod*.65:0)
  const tilt=(mood==='curious'?4:1.8)*Math.sin(time*1.2)
  const blink=time%4.6>3.08 && time%4.6<3.29 || time%9.2>3.52 && time%9.2<3.68
  // A quick pinna flick has an arrival, overshoot and settled pause.
  const flick=Math.exp(-(((time%5.1-1.45)/.22)**2))*Math.sin((time%5.1-1.45)*24)*12
  const otherFlick=Math.exp(-(((time%6.3-3.1)/.25)**2))*Math.sin((time%6.3-3.1)*22)*10
  const speech=level*7
  return {mood,blink,x,y,tilt,scale:1+(mood==='love'?pulse(time%1.6/1.6)*.04:0),
    leftEar:-24+speech+x*2+flick+(mood==='curious'?-8*gesture:mood==='happy'?nod*4:0)+(blink?4:0),
    rightEar:24-speech+x*2+otherFlick+(mood==='wink'?18*gesture:mood==='curious'?-7*gesture:mood==='happy'?-nod*4:0)-(blink?3:0)}
}

