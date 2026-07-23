#ifndef __STOREBUTTONWIDGET_H__
#define __STOREBUTTONWIDGET_H__

#include "SexyAppFramework/ButtonWidget.h"
#include "SexyAppFramework/ButtonListener.h"

namespace Sexy
{
	class WinFishApp;
	class GameObject;

	class StoreButtonWidget : public ButtonWidget
	{
	public:
		WinFishApp* mApp;
		GameObject* mProduct;
		int m0x128;
		SexyString m0x12c;
		bool m0x148;
		int m0x14c;
		int m0x150;
		int m0x154;
		int m0x158;

	public:
		StoreButtonWidget(int theId, ButtonListener* theButtonListener, Image* theButtonImage);
		virtual ~StoreButtonWidget();

		virtual void			Update();
		virtual void			Draw(Graphics* g);
		virtual void			DrawOverlay(Graphics* g);
		virtual void			MouseEnter();
		virtual void			MouseLeave();

		void					HandleMouseEvent(bool inside);
		GameObject*				GetProduct(bool removeProduct);
		void					SetUpButton(GameObject* theProduct, int theValue);
		void					SetPrice(int theValue);
		void					Bought();
		void					SetProductType(int theType, int theImageCel, int thePrice);
	};
}

#endif