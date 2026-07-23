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

#include "MusicInterface.h"
#include "SexyAppBase.h"

using namespace Sexy;

class DummyMusicInterface : public MusicInterface
{
public:
	DummyMusicInterface() {}
	virtual ~DummyMusicInterface() {};

	virtual bool			LoadMusic(int, const std::string&){return false;}
	virtual void 			PlayMusic(int, int, bool){}
	virtual void 			StopMusic(int){}
	virtual void 			PauseMusic(int){}
	virtual void 			ResumeMusic(int){}
	virtual void 			StopAllMusic(){}
	virtual void 			UnloadMusic(int){}
	virtual void 			UnloadAllMusic(){}
	virtual void 			PauseAllMusic(){}
	virtual void 			ResumeAllMusic(){}
	virtual void 			FadeIn(int, int, double, bool){}
	virtual void 			FadeOut(int, bool, double){}
	virtual void 			FadeOutAll(bool, double){}
	virtual void 			SetSongVolume(int, double){}
	virtual void 			SetSongMaxVolume(int, double){}
	virtual bool			IsPlaying(int){return false;};
	
	virtual void			SetVolume(double){}
	virtual void			SetMusicAmplify(int, double){}
	virtual void			Update(){}
};
