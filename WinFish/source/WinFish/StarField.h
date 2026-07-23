#ifndef __STARFIELD_H__
#define __STARFIELD_H__

#include "SexyAppFramework/Common.h"

namespace Sexy
{
	class GLImage;
	class Graphics;

	struct Star
	{
		float mX;
		float mY;
		float mVX;
		float mVY;
		uint32_t mColorValue;
	};

	typedef std::list<Star> StarList;

	class StarField
	{
	public:
		StarList mStarList;
		int mMaxStars;
		GLImage* mNebulaImage;

	public:
		StarField();
		virtual ~StarField();

		void				Init(int theMaxStars);
		void				AddStar(int theX, int theY);
		void				Update();
		void				Draw(Graphics* g, bool flag);
	};
}

#endif
