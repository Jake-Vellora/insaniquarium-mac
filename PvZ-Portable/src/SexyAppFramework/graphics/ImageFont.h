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

#ifndef __IMAGEFONT_H__
#define __IMAGEFONT_H__

#include "Font.h"
#include "misc/DescParser.h"
#include "SexyAppBase.h"
#include "SharedImage.h"
#include <atomic>

namespace Sexy
{

class SexyAppBase;
class Image;

typedef std::map<char32_t, int> CharIntMap;

class CharData
{
public:
	Rect					mImageRect;
	Point					mOffset;
	CharIntMap				mKerningOffsets;
	int						mWidth;
	int						mOrder;

public:
	CharData();
};

class FontData;
typedef std::map<char32_t, CharData> CharDataMap;

class FontLayer
{
public:	
	FontData*				mFontData;
	StringStringMap			mExtendedInfo;
	std::string				mLayerName;
	StringVector			mRequiredTags;
	StringVector			mExcludedTags;	
	//CharData				mCharData[256];	
	CharDataMap				mCharDataMap;
	Color					mColorMult;
	Color					mColorAdd;
	SharedImageRef			mImage;	
	int						mDrawMode;
	Point					mOffset;
	int						mSpacing;
	int						mMinPointSize;
	int						mMaxPointSize;
	int						mPointSize;
	int						mAscent;
	int						mAscentPadding; // How much space is above the avg uppercase char
	int						mHeight;		// 	
	int						mDefaultHeight; // Max height of font character image rects	
	int						mLineSpacingOffset; // This plus height should get added between lines
	int						mBaseOrder;
	bool					mUseAlphaCorrection;

public:
	FontLayer(FontData* theFontData);
	FontLayer(const FontLayer& theFontLayer);

	CharData*				GetCharData(char32_t theChar);
};

typedef std::map<char32_t, char32_t> CharMap;
typedef std::list<FontLayer> FontLayerList;
typedef std::map<std::string, FontLayer*> FontLayerMap;
typedef std::list<Rect> RectList;

class FontData : public DescParser
{
public:
	bool					mInitialized;
	std::atomic<int>		mRefCount;
	SexyAppBase*			mApp;		

	int						mDefaultPointSize;
	CharMap					mCharMap;
	FontLayerList			mFontLayerList;
	FontLayerMap			mFontLayerMap;

	std::string				mSourceFile;
	std::string				mFontErrorHeader;	

public:
	virtual bool			Error(const std::string& theError);

	bool					GetColorFromDataElement(DataElement *theElement, Color &theColor);
	bool					DataToLayer(DataElement* theSource, FontLayer** theFontLayer);
	virtual bool			HandleCommand(const ListDataElement& theParams);

public:
	FontData();
	virtual ~FontData();

	void					Ref();
	void					DeRef();

	bool					Load(SexyAppBase* theSexyApp, const std::string& theFontDescFileName);
	bool					LoadLegacy(Image* theFontImage, const std::string& theFontDescFileName);
};

typedef std::map<char32_t, Rect> CharRectMap;

class ActiveFontLayer
{
public:
	FontLayer*				mBaseFontLayer;

	Image*					mScaledImage;
	bool					mOwnsImage;
	CharRectMap				mScaledCharImageRects;

public:
	ActiveFontLayer();
	ActiveFontLayer(const ActiveFontLayer& theActiveFontLayer);
	virtual ~ActiveFontLayer();
};

typedef std::list<ActiveFontLayer> ActiveFontLayerList;

class RenderCommand
{
public:
	Image*					mImage;
	int						mDest[2];
	int						mSrc[4];
	int						mMode;
	Color					mColor;
	bool					mUseAlphaCorrection;
	RenderCommand*			mNext;
};

typedef std::multimap<int, RenderCommand> RenderCommandMap;

class ImageFont : public _Font
{
public:	
	FontData*				mFontData;
	int						mPointSize;
	StringVector			mTagVector;

	bool					mActiveListValid;
	ActiveFontLayerList		mActiveLayerList;
	double					mScale;
	bool					mForceScaledImagesWhite;

public:
	virtual void			GenerateActiveFontLayers();
	virtual void			DrawStringEx(Graphics* g, int theX, int theY, const std::string& theString, const Color& theColor, RectList* theDrawnAreas, int* theWidth);

public:
	ImageFont(SexyAppBase* theSexyApp, const std::string& theFontDescFileName);
	ImageFont(Image *theFontImage); // for constructing your own image font without a file descriptor
	ImageFont(const ImageFont& theImageFont);
	virtual ~ImageFont();

	// Deprecated
	ImageFont(Image* theFontImage, const std::string& theFontDescFileName);
	//ImageFont(const ImageFont& theImageFont, Image* theImage);
	
	virtual int				CharWidth(char32_t theChar);
	virtual int				CharWidthKern(char32_t theChar, char32_t thePrevChar);
	virtual int				StringWidth(const std::string& theString);
	virtual void			DrawString(Graphics* g, int theX, int theY, const std::string& theString, const Color& theColor, const Rect& theClipRect);

	virtual _Font*			Duplicate();

	virtual void			SetPointSize(int thePointSize);
	virtual int				GetPointSize();
	virtual void			SetScale(double theScale);
	virtual int				GetDefaultPointSize();
	virtual bool			AddTag(const std::string& theTagName);	
	virtual bool			RemoveTag(const std::string& theTagName);
	virtual bool			HasTag(const std::string& theTagName);
	virtual std::string		GetDefine(const std::string& theName);

	virtual void			Prepare();
	char32_t				GetMappedChar(char32_t theChar);
};

}

#endif //__IMAGEFONT_H__
