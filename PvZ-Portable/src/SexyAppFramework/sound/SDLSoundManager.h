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

#ifndef __SDLSOUNDMANAGER_H__
#define __SDLSOUNDMANAGER_H__

#include "SoundManager.h"
#include <SDL.h>
#include <SDL_mixer_ext/SDL_mixer_ext.h>

namespace Sexy
{

class SDLSoundInstance;

class SDLSoundManager : public SoundManager
{
	friend class SDLSoundInstance;

protected:
	bool					mInitializedMixer;
	Mix_Chunk*				mSourceSounds[MAX_SOURCE_SOUNDS];
	std::string				mSourceFileNames[MAX_SOURCE_SOUNDS];
	double					mBaseVolumes[MAX_SOURCE_SOUNDS];
	int						mBasePans[MAX_SOURCE_SOUNDS];
	SDLSoundInstance*		mPlayingSounds[MAX_CHANNELS];
	double					mMasterVolume;
	uint64_t				mLastReleaseTick;
	int						mMixerFreq;
	uint16_t				mMixerFormat;
	int						mMixerChannels;

protected:
	int						FindFreeChannel();
	bool					LoadAUSound(intptr_t theSfxID, const std::string& theFilename);
	void					ReleaseFreeChannels();

public:
	SDLSoundManager();
	virtual ~SDLSoundManager();

	virtual bool			Initialized();

	virtual bool			LoadSound(intptr_t theSfxID, const std::string& theFilename);
	virtual intptr_t		LoadSound(const std::string& theFilename);
	virtual void			ReleaseSound(intptr_t theSfxID);

	virtual void			SetVolume(double theVolume);
	virtual bool			SetBaseVolume(intptr_t theSfxID, double theBaseVolume);
	virtual bool			SetBasePan(intptr_t theSfxID, int theBasePan);

	virtual SoundInstance*	GetSoundInstance(intptr_t theSfxID);

	virtual void			ReleaseSounds();
	virtual void			ReleaseChannels();

	virtual double			GetMasterVolume();
	virtual void			SetMasterVolume(double theVolume);

	virtual void			Flush();
	virtual void			StopAllSounds();
	virtual intptr_t		GetFreeSoundId();
	virtual int				GetNumSounds();
};

}

#endif //__SDLSOUNDMANAGER_H__
