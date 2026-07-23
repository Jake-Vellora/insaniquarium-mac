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

#ifndef __COLOR_H__
#define __COLOR_H__

#include "Common.h"

namespace Sexy
{

class Color
{
public:
	int32_t mRed;
	int32_t mGreen;
	int32_t mBlue;
	int32_t mAlpha;

	static Color Black;
	static Color White;

public:
	Color();
	Color(int32_t theColor);
	Color(int32_t theColor, int32_t theAlpha);
	Color(int32_t theRed, int32_t theGreen, int32_t theBlue);
	Color(int32_t theRed, int32_t theGreen, int32_t theBlue, int32_t theAlpha);
	Color(const uchar* theElements);	
	Color(const int32_t* theElements);

	int32_t					GetRed() const;
	int32_t					GetGreen() const;
	int32_t					GetBlue() const;
	int32_t					GetAlpha() const;
	uint32_t				ToInt() const;
	uint32_t				ToGLColor() const;

	int32_t&				operator[](int32_t theIdx);
	int32_t					operator[](int32_t theIdx) const;	
};

bool operator==(const Color& theColor1, const Color& theColor2);
bool operator!=(const Color& theColor1, const Color& theColor2);

}

#endif //__COLOR_H__