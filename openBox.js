import fetch from 'node-fetch';
import { Transaction } from '@solana/web3.js';
import { Connection, clusterApiUrl } from '@solana/web3.js';

// Replace this with the actual connection setup
const connection = new Connection(clusterApiUrl('mainnet-beta'), 'confirmed');

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

const RETRY_DELAY_MS = 7000; // 지연 시간 설정 (7초)
const MAX_RETRIES = 3; // 최대 재시도 횟수

const sendTransaction = async (transaction, keyPair) => {
    try {
        transaction.partialSign(keyPair);
        const rawTransaction = transaction.serialize();
        const signature = await connection.sendRawTransaction(rawTransaction);
        await connection.confirmTransaction(signature);
        return signature;
    } catch (error) {
        throw new Error(`트랜잭션 전송 오류: ${error.message}`);
    }
};

export const openBox = async (keyPair, auth) => {
    let retries = 0; // 재시도 횟수

    while (retries <= MAX_RETRIES) {
        try {
            const response = await fetch('https://odyssey-api.sonic.game/user/rewards/mystery-box/build-tx', {
                headers: {
                    ...defaultHeaders,
                    'authorization': auth
                }
            });

            if (!response.ok) {
                throw new Error(`에러가 발생했습니다. status: ${response.status}`);
            }

            const data = await response.json();

            if (data.data) {
                const transactionBuffer = Buffer.from(data.data.hash, 'base64');
                const transaction = Transaction.from(transactionBuffer);

                // 트랜잭션 전송 및 확인
                const signature = await sendTransaction(transaction, keyPair);

                // 미스터리 박스 개봉 요청
                const openResponse = await fetch('https://odyssey-api.sonic.game/user/rewards/mystery-box/open', {
                    method: 'POST',
                    headers: {
                        ...defaultHeaders,
                        'authorization': auth
                    },
                    body: JSON.stringify({ 'hash': signature })
                });

                if (!openResponse.ok) {
                    throw new Error(`오류가 발생했습니다. status: ${openResponse.status}`);
                }

                const openData = await openResponse.json();

                // 성공적으로 미스터리 박스를 열었음
                return { success: true, message: `성공적으로 미스터리 박스를 열었습니다! ${openData.data.reward}` };
            } else {
                throw new Error('데이터가 없습니다.');
            }
        } catch (e) {
            console.error('미스터리 박스 개봉 오류:', e.message);

            retries++;
            if (retries > MAX_RETRIES) {
                // 최대 재시도 횟수를 초과한 경우 실패 메시지 반환
                return { success: false, message: '미스터리 박스 개봉 실패. 최대 재시도 횟수를 초과했습니다. 다음 단계로 넘어갑니다.' };
            }
            // 지연 시간 후 재시도
            await new Promise(resolve => setTimeout(resolve, RETRY_DELAY_MS));
        }
    }

    // 최대 재시도 횟수를 초과한 경우 실패 메시지 반환 (while 루프를 빠져나온 경우)
    return { success: false, message: '미스터리 박스 개봉 실패. 최대 재시도 횟수를 초과했습니다. 다음 단계로 넘어갑니다.' };
};
