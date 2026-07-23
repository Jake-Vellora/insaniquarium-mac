#ifndef __SCREENSAVERDIALOG_H__
#define __SCREENSAVERDIALOG_H__

#include "MoneyDialog.h"
#include "SexyAppFramework/CheckboxListener.h"

namespace Sexy
{
	class WinFishApp;
	class Checkbox;

	class ScreenSaverDialog : public MoneyDialog, public CheckboxListener
	{
	public:
		Checkbox* mSSEnabledCB;
		Checkbox* mSSSoundCB;
		Checkbox* mSSRotateBackdropsCB;
		Checkbox* mSSPeriodicDimCB;
		Checkbox* mSSShowMoneyCB;
		Checkbox* mSSPowerSaveCB;

	public:
		ScreenSaverDialog(WinFishApp* theApp);
		virtual ~ScreenSaverDialog();

		virtual void			AddedToManager(WidgetManager* theWidgetManager);
		virtual void			RemovedFromManager(WidgetManager* theWidgetManager);

		virtual void			Draw(Graphics* g);
		virtual void			Resize(int theX, int theY, int theWidth, int theHeight);

		virtual int				GetPreferredHeight(int theWidth);

		virtual void			WidgetClicked(int theId, bool theFlag);			//[77]

		virtual void			CheckboxChecked(int theId, bool checked);
	};
}

#endif
