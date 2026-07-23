/*
 * Copyright (C) 2026 Zhou Qiankang <wszqkzqk@qq.com>
 *
 * SPDX-License-Identifier: LGPL-3.0-or-later
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

#ifndef __TRAIL_H__
#define __TRAIL_H__

#include <cstdint>
#include "TodParticle.h"

#define MAX_TRAIL_TRIANGLES 38

enum TrailType : int32_t
{
	TRAIL_NONE = -1,
	TRAIL_ICE,
	NUM_TRAILS
};

enum TrailTracks : int32_t
{
	TRACK_WIDTH_OVER_LENGTH,
	TRACK_WIDTH_OVER_TIME,
	TRACK_ALPHA_OVER_LENGTH,
	TRACK_ALPHA_OVER_TIME,
	NUM_TRAIL_TRACKS
};

enum TrailFlags : int32_t
{
	TRAIL_FLAG_LOOPS = 0
};

class TrailParams
{
public:
	TrailType				mTrailType;
	const char*				mTrailFileName;
};

extern int gTrailParamArraySize;  //[0x6A9F28]
extern TrailParams* gTrailParamArray;  //[0x6A9F2C]

extern TrailParams gLawnTrailArray[static_cast<int>(TrailType::NUM_TRAILS)];  //0x6A19F4

class TrailDefinition
{
public:
	Image*					mImage;
	int						mMaxPoints;
	float					mMinPointDistance;
	int						mTrailFlags;
	FloatParameterTrack		mTrailDuration;
	FloatParameterTrack		mWidthOverLength;
	FloatParameterTrack		mWidthOverTime;
	FloatParameterTrack		mAlphaOverLength;
	FloatParameterTrack		mAlphaOverTime;

public:
	TrailDefinition();
	~TrailDefinition();
};
bool						TrailLoadADef(TrailDefinition* theTrailDef, const char* theTrailFileName);
void						TrailLoadDefinitions(TrailParams* theTrailParamArray, int theTrailParamArraySize);
void						TrailFreeDefinitions();

extern int gTrailDefCount;  //[0x6A9F20]
extern TrailDefinition* gTrailDefArray;  //[0x6A9F24]

// #################################################################################################### //

class TrailPoint
{
public:
	SexyVector2				aPos;

public:
	TrailPoint();
};

class TrailHolder;

class Trail
{
public:
	TrailPoint				mTrailPoints[20];		//+0x0
	int32_t					mNumTrailPoints;		//+0xA0
	bool					mDead;					//+0xA4
	int32_t					mRenderOrder;			//+0xA8
	int32_t					mTrailAge;				//+0xAC
	int32_t					mTrailDuration;			//+0xB0
	TrailDefinition*		mDefinition;			//+0xB4
	TrailHolder*			mTrailHolder;			//+0xB8
	float					mTrailInterp[4];		//+0xBC
	SexyVector2				mTrailCenter;			//+0xCC
	bool					mIsAttachment;			//+0xD4
	Color					mColorOverride;			//+0xD8

public:
	Trail();

	void					Update();
	void					Draw(Graphics* g);
	void					AddPoint(float x, float y);
	bool					GetNormalAtPoint(int nIndex, SexyVector2& theNormal);
};

class TrailHolder
{
public:
	DataArray<Trail>		mTrails;

public:
	TrailHolder() { ; }
	~TrailHolder() { DisposeHolder(); }

	void					InitializeHolder();
	void					DisposeHolder();
	Trail*					AllocTrail(int theRenderOrder, TrailType theTrailType);
	Trail*					AllocTrailFromDef(int theRenderOrder, TrailDefinition* theDefinition);
};

#endif
