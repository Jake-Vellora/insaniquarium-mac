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

#include "SDLMusicInterface.h"
#include "paklib/PakInterface.h"

using namespace Sexy;

// The app hands us a 0..1 volume and we map it onto 0..kMaxMusicVolume rather
// than the mixer's full 0..MIX_MAX_VOLUME range. The mixer's own default is
// MIX_MAX_VOLUME, which is louder than anything the app can ask for, so it must
// never be left in place once we exist.
static const int kMaxMusicVolume = 80;

SDLMusicInfo::SDLMusicInfo()
{
	mVolume = 0.0;
	mVolumeAdd = 0.0;
	mVolumeCap = 1.0;
	mStopOnFade = false;
	mHMusic = 0;
}

SDLMusicInterface::SDLMusicInterface()
{
	// SexyAppBase::Init constructs us after the mixer is already open and calls
	// SetVolume immediately afterwards, but start from our own ceiling rather
	// than the mixer's louder default so nothing can slip through in between.
	mGlobalVolume = kMaxMusicVolume;
	ApplyGlobalVolume();
}

SDLMusicInterface::~SDLMusicInterface()
{
	Mix_HaltMusic();
}

bool SDLMusicInterface::LoadMusic(int theSongId, const std::string& theFileName)
{
	Mix_Music* aHMusic = 0;
	
	std::string anExt;
	size_t aDotPos = theFileName.find_last_of('.');
	if (aDotPos!=std::string::npos)
		anExt = StringToLower(theFileName.substr(aDotPos+1));

	aHMusic = Mix_LoadMUS(theFileName.c_str());

	if (aHMusic==0)
		return false;
	
	SDLMusicInfo aMusicInfo;	
	aMusicInfo.mHMusic = aHMusic;
	mMusicMap.insert(SDLMusicMap::value_type(theSongId, aMusicInfo));

	return true;
}

void SDLMusicInterface::PlayMusic(int theSongId, int theOffset, bool noLoop)
{
	SDLMusicMap::iterator anItr = mMusicMap.find(theSongId);
	if (anItr != mMusicMap.end())
	{
		SDLMusicInfo* aMusicInfo = &anItr->second;
		aMusicInfo->mVolume = aMusicInfo->mVolumeCap;
		aMusicInfo->mVolumeAdd = 0.0;
		aMusicInfo->mStopOnFade = noLoop;

		Mix_HaltMusicStream(aMusicInfo->mHMusic);
		Mix_PlayMusicStream(aMusicInfo->mHMusic, (noLoop) ? 0 : -1);
		if (theOffset > 0)
			Mix_ModMusicStreamJumpToOrder(aMusicInfo->mHMusic, theOffset);
	}
}

void SDLMusicInterface::StopMusic(int theSongId)
{
	Mix_HaltMusic();

	SDLMusicMap::iterator anItr = mMusicMap.find(theSongId);
	if (anItr != mMusicMap.end())
	{
		SDLMusicInfo* aMusicInfo = &anItr->second;
		aMusicInfo->mVolume = 0.0;
		Mix_HaltMusicStream(aMusicInfo->mHMusic);
	}
}

void SDLMusicInterface::PauseMusic(int theSongId)
{
	SDLMusicMap::iterator anItr = mMusicMap.find(theSongId);
	if (anItr != mMusicMap.end())
	{
		SDLMusicInfo* aMusicInfo = &anItr->second;
		Mix_PauseMusicStream(aMusicInfo->mHMusic);
	}
}

void SDLMusicInterface::ResumeMusic(int theSongId)
{
	SDLMusicMap::iterator anItr = mMusicMap.find(theSongId);
	if (anItr != mMusicMap.end())
	{
		SDLMusicInfo* aMusicInfo = &anItr->second;
		//gBass->BASS_ChannelResume(aMusicInfo->GetHandle());
		Mix_ResumeMusicStream(aMusicInfo->mHMusic);
	}
}

void SDLMusicInterface::StopAllMusic()
{
	SDLMusicMap::iterator anItr = mMusicMap.begin();
	while (anItr != mMusicMap.end())
	{
		SDLMusicInfo* aMusicInfo = &anItr->second;
		aMusicInfo->mVolume = 0.0;
		Mix_HaltMusicStream(aMusicInfo->mHMusic);
		++anItr;
	}
}

void SDLMusicInterface::UnloadMusic(int theSongId)
{
	StopMusic(theSongId);
	
	SDLMusicMap::iterator anItr = mMusicMap.find(theSongId);
	if (anItr != mMusicMap.end())
	{
		SDLMusicInfo* aMusicInfo = &anItr->second;
		Mix_FreeMusic(aMusicInfo->mHMusic);

		mMusicMap.erase(anItr);
	}
}

void SDLMusicInterface::UnloadAllMusic()
{
	StopAllMusic();
	for (SDLMusicMap::iterator anItr = mMusicMap.begin(); anItr != mMusicMap.end(); ++anItr)
	{
		SDLMusicInfo* aMusicInfo = &anItr->second;
		Mix_FreeMusic(aMusicInfo->mHMusic);
	}
	mMusicMap.clear();
}

void SDLMusicInterface::PauseAllMusic()
{
	for (SDLMusicMap::iterator anItr = mMusicMap.begin(); anItr != mMusicMap.end(); ++anItr)
	{
		SDLMusicInfo* aMusicInfo = &anItr->second;
		if (Mix_PlayingMusicStream(aMusicInfo->mHMusic) && !Mix_PausedMusicStream(aMusicInfo->mHMusic))
			Mix_PauseMusicStream(aMusicInfo->mHMusic);
	}
}

void SDLMusicInterface::ResumeAllMusic()
{
	for (SDLMusicMap::iterator anItr = mMusicMap.begin(); anItr != mMusicMap.end(); ++anItr)
	{
		SDLMusicInfo* aMusicInfo = &anItr->second;
		if (Mix_PausedMusicStream(aMusicInfo->mHMusic))
			Mix_ResumeMusicStream(aMusicInfo->mHMusic);
	}
}

void SDLMusicInterface::FadeIn(int theSongId, int theOffset, double theSpeed, bool noLoop)
{
	SDLMusicMap::iterator anItr = mMusicMap.find(theSongId);
	if (anItr != mMusicMap.end())
	{
		SDLMusicInfo* aMusicInfo = &anItr->second;
				
		aMusicInfo->mVolumeAdd = theSpeed;
		aMusicInfo->mStopOnFade = noLoop;

		Mix_HaltMusicStream(aMusicInfo->mHMusic);
		Mix_PlayMusicStream(aMusicInfo->mHMusic, (noLoop) ? 0 : -1);
		if (theOffset > 0)
			Mix_ModMusicStreamJumpToOrder(aMusicInfo->mHMusic, theOffset);

	}
}

void SDLMusicInterface::FadeOut(int theSongId, bool stopSong, double theSpeed)
{
	SDLMusicMap::iterator anItr = mMusicMap.find(theSongId);
	if (anItr != mMusicMap.end())
	{		
		SDLMusicInfo* aMusicInfo = &anItr->second;
		
		if (aMusicInfo->mVolume != 0.0)
		{
			aMusicInfo->mVolumeAdd = -theSpeed;			
		}

		aMusicInfo->mStopOnFade = stopSong;
	}
}

void SDLMusicInterface::FadeOutAll(bool stopSong, double theSpeed)
{
	SDLMusicMap::iterator anItr = mMusicMap.begin();
	while (anItr != mMusicMap.end())
	{
		SDLMusicInfo* aMusicInfo = &anItr->second;
				
		aMusicInfo->mVolumeAdd = -theSpeed;
		aMusicInfo->mStopOnFade = stopSong;

		++anItr;
	}
}

void SDLMusicInterface::SetSongVolume(int theSongId, double theVolume)
{
	SDLMusicMap::iterator anItr = mMusicMap.find(theSongId);
	if (anItr != mMusicMap.end())
	{		
		SDLMusicInfo* aMusicInfo = &anItr->second;

		aMusicInfo->mVolume = theVolume;
		//gBass->BASS_ChannelSetAttribute(aMusicInfo->GetHandle(), BASS_ATTRIB_VOL, (int) (aMusicInfo->mVolume));
		Mix_VolumeMusicStream(aMusicInfo->mHMusic, (int)(aMusicInfo->mVolume*128));
	}
}

void SDLMusicInterface::SetSongMaxVolume(int theSongId, double theMaxVolume)
{
	SDLMusicMap::iterator anItr = mMusicMap.find(theSongId);
	if (anItr != mMusicMap.end())
	{		
		SDLMusicInfo* aMusicInfo = &anItr->second;

		aMusicInfo->mVolumeCap = theMaxVolume;
		aMusicInfo->mVolume = std::min(aMusicInfo->mVolume, theMaxVolume);
		Mix_VolumeMusicStream(aMusicInfo->mHMusic, (int)(aMusicInfo->mVolume*128));
	}
}

bool SDLMusicInterface::IsPlaying(int theSongId)
{
	SDLMusicMap::iterator anItr = mMusicMap.find(theSongId);
	if (anItr != mMusicMap.end())
	{		
		SDLMusicInfo* aMusicInfo = &anItr->second;
		return Mix_PlayingMusicStream(aMusicInfo->mHMusic);
	}

	return false;
}

void SDLMusicInterface::SetVolume(double theVolume)
{
	mGlobalVolume = (int)(theVolume * kMaxMusicVolume);
	// Apply it here, not only on the next Update(). Music starts from the
	// loading thread well before the next frame runs, and until Update() had
	// run the mixer was still on its own default of MIX_MAX_VOLUME, so the
	// first ~100 ms of the title music played at full volume no matter what the
	// player had chosen - including when they had music turned off entirely.
	ApplyGlobalVolume();
}

// Mix_VolumeMusic sets the volume newly loaded songs inherit and the volume of
// the song playing right now; Mix_VolumeMusicGeneral is the master applied to
// every stream as it is mixed. Update() writes both every frame, so write both
// here too and the level never changes when the frame loop catches up.
void SDLMusicInterface::ApplyGlobalVolume()
{
	Mix_VolumeMusic(mGlobalVolume);
	Mix_VolumeMusicGeneral(mGlobalVolume);
}

void SDLMusicInterface::SetMusicAmplify(int theSongId, double theAmp)
{
	
}

void SDLMusicInterface::Update()
{
	ApplyGlobalVolume();

	SDLMusicMap::iterator anItr = mMusicMap.begin();
	while (anItr != mMusicMap.end())
	{
		SDLMusicInfo* aMusicInfo = &anItr->second;

		if (aMusicInfo->mVolumeAdd != 0.0)
		{
			aMusicInfo->mVolume += aMusicInfo->mVolumeAdd;
			
			if (aMusicInfo->mVolume > aMusicInfo->mVolumeCap)
			{
				aMusicInfo->mVolume = aMusicInfo->mVolumeCap;
				aMusicInfo->mVolumeAdd = 0.0;
			}
			else if (aMusicInfo->mVolume < 0.0)
			{
				aMusicInfo->mVolume = 0.0;
				aMusicInfo->mVolumeAdd = 0.0;

				if (aMusicInfo->mStopOnFade)
					Mix_HaltMusicStream(aMusicInfo->mHMusic);
			}

			//gBass->BASS_ChannelSetAttribute(aMusicInfo->GetHandle(), BASS_ATTRIB_VOL, (int) (aMusicInfo->mVolume));
			Mix_VolumeMusicStream(aMusicInfo->mHMusic, (int)(aMusicInfo->mVolume*128));
		}

		++anItr;
	}
}

// functions for dealing with MODs
int SDLMusicInterface::GetMusicOrder(int theSongId)
{
	SDLMusicMap::iterator anItr = mMusicMap.find(theSongId);
	if (anItr != mMusicMap.end())
	{
		SDLMusicInfo* aMusicInfo = &anItr->second;
		int aPosition = -1;
		Mix_ModMusicStreamGetOrder(aMusicInfo->mHMusic, &aPosition);
		return aPosition;
	}
	return -1;
}
