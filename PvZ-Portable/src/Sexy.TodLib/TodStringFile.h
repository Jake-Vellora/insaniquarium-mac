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

#ifndef __TODSTRINGFILE_H__
#define __TODSTRINGFILE_H__

#include "graphics/Graphics.h"
#include "../ConstEnums.h"
using namespace Sexy;

//enum DrawStringJustification;
enum TodStringFormatFlag
{
    TOD_FORMAT_IGNORE_NEWLINES,
    TOD_FORMAT_HIDE_UNTIL_MAGNETSHROOM
};

class TodStringListFormat
{
public:
    const char*     mFormatName;
    _Font**          mNewFont;
    Color           mNewColor;
    int             mLineSpacingOffset;
    unsigned int    mFormatFlags;

public:
    TodStringListFormat();
    TodStringListFormat(const char* theFormatName, _Font** theFont, const Color& theColor, int theLineSpacingOffset, unsigned int theFormatFlags);
};
extern int gTodStringFormatCount;               //[0x69DE4C]
extern TodStringListFormat* gTodStringFormats;  //[0x69DA34]

extern const int gLawnStringFormatCount;
extern TodStringListFormat gLawnStringFormats[12];  //0x6A5010

void                TodStringListSetColors(TodStringListFormat* theFormats, int theCount);
void                TodWriteStringSetFormat(const char* theFormat, TodStringListFormat& theCurrentFormat);
bool                TodStringListReadName(const char*& thePtr, std::string& theName);
bool                TodStringListReadValue(const char*& thePtr, std::string& theValue);
bool                TodStringListReadItems(const char* theFileText);
bool                TodStringListReadFile(const char* theFileName);
void                TodStringListLoad(const char* theFileName);
std::string          TodStringListFind(const std::string& theName);
std::string			TodStringTranslate(const std::string& theString);
std::string			TodStringTranslate(const char* theString);
bool                TodStringListExists(const std::string& theString);
void                TodStringRemoveReturnChars(std::string& theString);
bool                CharIsSpaceInFormat(char theChar, const TodStringListFormat& theCurrentFormat);
int                 TodWriteString(Graphics* g, const std::string& theString, int theX, int theY, TodStringListFormat& theCurrentFormat, int theWidth, DrawStringJustification theJustification, bool drawString, int theOffset, int theLength);
/*inline*/ int      TodWriteWordWrappedHelper(Graphics* g, const std::string& theString, int theX, int theY, TodStringListFormat& theCurrentFormat, int theWidth, DrawStringJustification theJustification, bool drawString, int theOffset, int theLength, int theMaxChars);
int                 TodDrawStringWrappedHelper(Graphics* g, const std::string& theText, const Rect& theRect, _Font* theFont, const Color& theColor, DrawStringJustification theJustification, bool drawString);
/*inline*/ void		TodDrawStringWrapped(Graphics* g, const std::string& theText, const Rect& theRect, _Font* theFont, const Color& theColor, DrawStringJustification theJustification);

#endif  //__TODSTRINGFILE_H__