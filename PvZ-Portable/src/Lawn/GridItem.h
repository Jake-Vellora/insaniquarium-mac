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

#ifndef __GRIDITEM_H__
#define __GRIDITEM_H__

#include <cstdint>
#include "../ConstEnums.h"

#define NUM_MOTION_TRAIL_FRAMES 12

class LawnApp;
class Board;
class Zombie;
namespace Sexy
{
	class Graphics;
};

class MotionTrailFrame
{
public:
	float					mPosX;
	float					mPosY;
	float					mAnimTime;
};

class GridItem
{
public:
	LawnApp*				mApp;											//+0x0
	Board*					mBoard;											//+0x4
	GridItemType			mGridItemType;									//+0x8
	GridItemState			mGridItemState;									//+0xC
	int32_t					mGridX;											//+0x10
	int32_t					mGridY;											//+0x14
	int32_t					mGridItemCounter;								//+0x18
	int32_t					mRenderOrder;									//+0x1C
	bool					mDead;											//+0x20
	float					mPosX;											//+0x24
	float					mPosY;											//+0x28
	float					mGoalX;											//+0x2C
	float					mGoalY;											//+0x30
	ReanimationID			mGridItemReanimID;								//+0x34
	ParticleSystemID		mGridItemParticleID;							//+0x38
	ZombieType				mZombieType;									//+0x3C
	SeedType				mSeedType;										//+0x40
	ScaryPotType			mScaryPotType;									//+0x44
	bool					mHighlighted;									//+0x48
	int32_t					mTransparentCounter;							//+0x4C
	int32_t					mSunCount;										//+0x50
	MotionTrailFrame		mMotionTrailFrames[NUM_MOTION_TRAIL_FRAMES];	//+0x54
	int32_t					mMotionTrailCount;								//+0xE4

public:
	GridItem();

	void					DrawLadder(Sexy::Graphics* g);
	void					DrawCrater(Sexy::Graphics* g);
	void					DrawGraveStone(Sexy::Graphics* g);
	void					GridItemDie();
	void					AddGraveStoneParticles();
	void					DrawGridItem(Sexy::Graphics* g);
	void					DrawGridItemOverlay(Sexy::Graphics* g);
	void					OpenPortal();
	void					Update();
	void					ClosePortal();
	void					DrawScaryPot(Sexy::Graphics* g);
	void					UpdateScaryPot();
	void					UpdatePortal();
	void					DrawSquirrel(Sexy::Graphics* g);
	void					UpdateRake();
	Zombie*					RakeFindZombie();
	void					DrawIZombieBrain(Sexy::Graphics* g);
	void					UpdateBrain();
	void					DrawStinky(Sexy::Graphics* g);
	/*inline*/ bool			IsOpenPortal();
};

#endif
