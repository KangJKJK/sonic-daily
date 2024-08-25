// openBox.js
import { Transaction } from '@solana/web3.js';
import fetch from 'node-fetch';

export const openBox = async (keyPair, auth) => {
    let success = false;
    while (!success) {
        try {
            const data = await fetch('https://odyssey-api.sonic.game/user/rewards/mystery-box/build-tx', {
                headers: {
                    'accept': '*/*',
                    'accept-language': 'en-US,en;q=0.7',
                    'content-type': 'application/json',
                    'authorization': auth
                }
            }).then(res => res.json());

            if (data.data) {
                const transactionBuffer = Buffer.from(data.data.hash, "base64");
                const transaction = Transaction.from(transactionBuffer);
                transaction.partialSign(keyPair);
                const signature = await sendTransaction(transaction, keyPair);

                const open = await fetch('https://odyssey-api.sonic.game/user/rewards/mystery-box/open', {
                    method: 'POST',
                    headers: {
                        'accept': '*/*',
                        'accept-language': 'en-US,en;q=0.7',
                        'content-type': 'application/json',
                        'authorization': auth
                    },
                    body: JSON.stringify({ 'hash': signature })
                }).then(res => res.json());

                success = true;
                return `성공적으로 미스터리 박스를 열었습니다, ${open.data.reward}!`;
            }
        } catch (e) {
            console.error('미스터리 박스 개봉 오류:', e);
            await new Promise(resolve => setTimeout(resolve, 5000)); // 5초 대기 후 재시도
        }
    }
};
