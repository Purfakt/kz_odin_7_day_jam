package game

import "core:math/rand"
import rl "vendor:raylib"


Audio :: struct {
	volume:    f32,
	music:     rl.Music,
	step:      rl.Sound,
	torch:     rl.Sound,
	torch_on:  rl.Sound,
	torch_off: rl.Sound,
	exit:      rl.Sound,
}

init_sounds :: proc() -> Audio {
	music := rl.LoadMusicStream("assets/music.mp3")
	step := rl.LoadSound("assets/step.wav")
	exit := rl.LoadSound("assets/exit.wav")
	torch := rl.LoadSound("assets/torch.wav")
	torch_on := rl.LoadSound("assets/torch-on.wav")
	torch_off := rl.LoadSound("assets/torch-off.wav")

	return Audio {
		volume = 1,
		music = music,
		step = step,
		torch = torch,
		torch_on = torch_on,
		torch_off = torch_off,
		exit = exit,
	}
}

set_audio_level :: proc(audio_level: f32) {
	gm.audio.volume = audio_level
	rl.SetMusicVolume(gm.audio.music, audio_level)
	rl.SetSoundVolume(gm.audio.step, audio_level)
	rl.SetSoundVolume(gm.audio.exit, audio_level)
	rl.SetSoundVolume(gm.audio.torch, audio_level)
	rl.SetSoundVolume(gm.audio.torch_on, audio_level)
	rl.SetSoundVolume(gm.audio.torch_off, audio_level)
}

destroy_sounds :: proc() {
	rl.UnloadMusicStream(gm.audio.music)
	rl.UnloadSound(gm.audio.step)
	rl.UnloadSound(gm.audio.exit)
	rl.UnloadSound(gm.audio.torch)
	rl.UnloadSound(gm.audio.torch_on)
	rl.UnloadSound(gm.audio.torch_off)
}

play_music :: proc() {
	music := gm.audio.music
	if rl.IsMusicReady(music) && !rl.IsMusicStreamPlaying(music) {
		rl.PlayMusicStream(music)
	}

	if rl.IsMusicStreamPlaying(music) {
		rl.UpdateMusicStream(music)
	}
}

play_step_sound :: proc() {
	sound := gm.audio.step
	pitch := rand.float32() * 0.5 + 0.5
	rl.SetSoundPitch(sound, pitch)
	rl.PlaySound(sound)
}

play_torch_item_sound :: proc() {
	rl.PlaySound(gm.audio.torch)
}

play_torch_on_sound :: proc() {
	rl.PlaySound(gm.audio.torch_on)
}

play_torch_off_sound :: proc() {
	rl.PlaySound(gm.audio.torch_off)
}

play_exit_sound :: proc() {
	rl.PlaySound(gm.audio.exit)
}
