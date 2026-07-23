#ifndef __MESSAGEWIDGET_H__
#define __MESSAGEWIDGET_H__

#include "SexyAppFramework/Widget.h"
#include "DataSync.h"

namespace Sexy
{
	class WinFishApp;

	class MessageWidget : public Widget
	{
	public:
		WinFishApp* mApp;
		SexyString mMessage;
		Color mColor1;
		Color mColor2;
		int mUnusedInt;
		Font* mFont;
		int mMessageTimer;
		bool mIsBlinking;
		int mMessageId;

	public:
		MessageWidget(WinFishApp* theApp, SexyString theMessage);
		virtual ~MessageWidget();

		virtual void			Update();
		virtual void			Draw(Graphics* g);

		void					Sync(DataSync& theSync);
	};
}

#endif