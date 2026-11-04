// 인앱 결제: 지금은 "광고 제거" 상품 하나. 상점·아이템이 생기면 여기에 상품을 늘린다.
//
// 출시 전 할 일: Play Console 에서 관리형 상품 `remove_ads` 를 만들고, 네이티브 결제 어댑터를 연결한다
// (예: cordova-plugin-purchase 또는 RevenueCat). 연결 전에는 개발용 어댑터가 결제 없이 바로 지급한다.
import { isNative } from "../platform";

export const PRODUCTS = { removeAds: "remove_ads" } as const;
export type ProductId = (typeof PRODUCTS)[keyof typeof PRODUCTS];

export interface Billing {
  readonly available: boolean;
  purchase(id: ProductId): Promise<boolean>;
  /** 기기를 바꾸거나 재설치했을 때 구매 복원 */
  restore(): Promise<ProductId[]>;
}

class DevBilling implements Billing {
  readonly available = true;
  async purchase(_id: ProductId) { return true; }
  async restore() { return []; }
}

class NotConnectedBilling implements Billing {
  readonly available = false;
  async purchase() { return false; }
  async restore() { return []; }
}

export const billing: Billing = isNative ? new NotConnectedBilling() : new DevBilling();
