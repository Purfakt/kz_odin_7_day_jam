package game

import "core:math/rand"
import rl "vendor:raylib"


Sounds :: struct {
	step:      rl.Sound,
	torch:     rl.Sound,
	torch_on:  rl.Sound,
	torch_off: rl.Sound,
	exit:      rl.Sound,
}

init_sounds :: proc() -> Sounds {
	step := rl.LoadSound("assets/step2.wav")
	exit := rl.LoadSound("assets/exit.wav")
	torch := rl.LoadSound("assets/torch.wav")
	torch_on := rl.LoadSound("assets/torch-on.wav")
	torch_off := rl.LoadSound("assets/torch-off.wav")

	rl.SetSoundVolume(torch, 0.2)
	rl.SetSoundVolume(torch_on, 0.2)
	rl.SetSoundVolume(torch_off, 0.2)

	return Sounds {
		step = step,
		torch = torch,
		torch_on = torch_on,
		torch_off = torch_off,
		exit = exit,
	}
}

destroy_sounds :: proc(sounds: ^Sounds) {
	rl.UnloadSound(sounds.step)
}

play_step_sound :: proc() {
	sound := gm.sounds.step
	pitch := rand.float32() * 0.5 + 0.5
	rl.SetSoundPitch(sound, pitch)
	rl.PlaySound(sound)
}

play_torch_item_sound :: proc() {
	rl.PlaySound(gm.sounds.torch)
}

play_torch_on_sound :: proc() {
	rl.PlaySound(gm.sounds.torch_on)
}

play_torch_off_sound :: proc() {
	rl.PlaySound(gm.sounds.torch_off)
}

play_exit_sound :: proc() {
	rl.PlaySound(gm.sounds.exit)
}
