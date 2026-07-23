#ifndef __NEWUSERDIALOG_H__
#define __NEWUSERDIALOG_H__

#include "MoneyDialog.h"
#include "SexyAppFramework/ButtonListener.h"
#include "SexyAppFramework/EditListener.h"

namespace Sexy
{
	class WinFishApp;
	class EditWidget;

	class NewUserDialog : public MoneyDialog, public EditListener
	{
	public:
		WinFishApp*				mApp2;
		EditWidget*				mEditWidget;

	public:
		NewUserDialog(WinFishApp* theApp, bool theRename);
		virtual ~NewUserDialog();

		virtual void			Draw(Graphics* g);

		virtual void			AddedToManager(WidgetManager* theWidgetManager);
		virtual void			RemovedFromManager(WidgetManager* theWidgetManager);

		virtual int				GetPreferredHeight(int theWidth);

		virtual void			Resize(int theX, int theY, int theWidth, int theHeight);

		virtual void			EditWidgetText(int theId, const SexyString& theString);

		virtual bool			AllowChar(int theId, SexyChar theChar);

		SexyString				CleanString();

	};
}

#endif
