import { Transaction } from '@solana/web3.js';
import fetch from 'node-fetch';

// 공통 헤더를 설정하는 객체
const defaultHeaders = {
    'accept': '*/*',
    'accept-language': 'en-US,en;q=0.7',
    'content-type': 'application/json',
    'priority': 'u=1, i',
    'sec-ch-ua': '"Not/A)Brand";v="8", "Chromium";v="126", "Brave";v="126"',
    'sec-ch-ua-mobile': '?0',
    'sec-ch-ua-platform': '"Windows"',
    'sec-fetch-dest': 'empty',
    'sec-fetch-mode': 'cors',
    'sec-fetch-site': 'same-site',
    'sec-gpc': '1',
    'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36'
};

export const openBox = async (keyPair, auth) => {
    let success = false;
    while (!success) {
        try {
            // 미스터리 박스 거래 생성 요청
            const data = await fetch('https://odyssey-api.sonic.game/user/rewards/mystery-box/build-tx', {
                headers: {
                    ...defaultHeaders,
                    'authorization': auth
                }
            }).then(res => res.json());

            if (data.data) {
                const transactionBuffer = Buffer.from(data.data.hash, 'base64');
                const transaction = Transaction.from(transactionBuffer);
                transaction.partialSign(keyPair);

                // 트랜잭션 전송
                const signature = await sendTransaction(transaction, keyPair);

                // 미스터리 박스 개봉 요청
                const open = await fetch('https://odyssey-api.sonic.game/user/rewards/mystery-box/open', {
                    method: 'POST',
                    headers: {
                        ...defaultHeaders,
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
