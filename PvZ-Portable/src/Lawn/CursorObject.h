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

#ifndef __CURSOROBJECT_H__
#define __CURSOROBJECT_H__

#include <cstdint>
#include "GameObject.h"

class CursorObject : public GameObject
{
public:
	int32_t					mSeedBankIndex;			//+0x24
	SeedType				mType;					//+0x28
	SeedType				mImitaterType;			//+0x2C
	CursorType				mCursorType;			//+0x30
	CoinID					mCoinID;				//+0x34
	PlantID					mGlovePlantID;			//+0x38
	PlantID					mDuplicatorPlantID;		//+0x3C
	PlantID					mCobCannonPlantID;		//+0x40
	int32_t					mHammerDownCounter;		//+0x44
	ReanimationID			mReanimCursorID;		//+0x48

public:
	CursorObject();

	void					Update();
	void					Draw(Graphics* g);
	void					Die();
};

class CursorPreview : public GameObject
{
public:
	int32_t					mGridX;
	int32_t					mGridY;

public:
	CursorPreview();

	void					Update();
	void					Draw(Graphics* g);
};

#endif
