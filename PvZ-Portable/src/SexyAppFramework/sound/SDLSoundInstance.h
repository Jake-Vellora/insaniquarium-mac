/*
 * Portions of this file are based on the PopCap Games Framework
 * Copyright (C) 2005-2009 PopCap Games, Inc.
 * 
 * Copyright (C) 2026 Zhou Qiankang <wszqkzqk@qq.com>
 *
 * SPDX-License-Identifier: LGPL-3.0-or-later AND LicenseRef-PopCap
 *
 * This file is part of PvZ-Portable.
 *
 * PvZ-Portable is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * PvZ-Portable is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with PvZ-Portable. If not, see <https://www.gnu.org/licenses/>.
 */

#ifndef __SDLSOUNDINSTANCE_H__
#define __SDLSOUNDINSTANCE_H__

#include "SoundInstance.h"
#include <SDL.h>
#include <SDL_mixer.h>

namespace Sexy
{

class SDLSoundManager;
class SDLSoundInstance;

// SDL_mixer chunk pitching
// https://gist.github.com/hydren/ea794e65e95c7713c00c88f74b71f8b1
struct SDLSoundPitchHandler
{
	SDLSoundInstance* self;
	const Mix_Chunk* chunk;
	const float* speed;  /* ptr to the desired playback speed */
	float position;  /* current position of the sound, in ms */
	int altered;   /* false if this playback has never been pitched. */

	// read-only!
	int loop;       /* whether this is a looped playback */
	int duration;   /* the duration of the sound, in ms */
	int chunk_size;  /* the size of the sound, as a number of indexes (or sample points). thinks of this as a array size when using the proper array type (instead of just Uint8*). */
	int self_halt;   /* flags whether playback should be halted by this callback when playback is finished */
};

class SDLSoundInstance : public SoundInstance
{
	friend class SDLSoundManager;

protected:
	SDLSoundManager*		mSoundManagerP;
	Mix_Chunk*				mMixChunk;
	bool					mAutoRelease;
	bool					mHasPlayed;
	bool					mReleased;
	int						mReservedChannel;
	int						mChannel;

	int						mBasePan;
	double					mBaseVolume;

	int						mPan;
	double					mVolume;	
	float					mPitch;
	SDLSoundPitchHandler	mPitchHandler;

	uint32_t				mDefaultFrequency;

protected:
	void					RehupVolume();
	void					RehupPan();
	uint16_t				FormatSampleSize(uint16_t format);
	int						GetChunkDurationMS(int chunkSize);
	void					CreateSoundPitchHandler(const Mix_Chunk* chunk, const float* speed, int loop, int self_halt);
	static void				PitchHandlerFuncCallback(int mix_channel, void* stream, int length, void* user_data);

public:
	SDLSoundInstance(SDLSoundManager* theSoundManager, Mix_Chunk* theSourceSound, int theReservedChannel = -1);
	virtual ~SDLSoundInstance();
	virtual void			Release();
		
	virtual void			SetBaseVolume(double theBaseVolume);
	virtual void			SetBasePan(int theBasePan);

	virtual void			AdjustPitch(double theNumSteps);

	virtual void			SetVolume(double theVolume); 
	virtual void			SetPan(int thePosition); //-hundredth db to +hundredth db = left to right

	virtual bool			Play(bool looping, bool autoRelease);
	virtual void			Stop();
	virtual bool			IsPlaying();
	virtual bool			IsReleased();
	virtual double			GetVolume();
};

}

#endif //__SOUNDINSTANCE_H__