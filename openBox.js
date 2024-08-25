import fetch from 'node-fetch';

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

const MAX_RETRIES = 5; // 최대 재시도 횟수

export const openBox = async (keyPair, auth) => {
    let success = false;
    let retries = 0; // 재시도 횟수

    while (!success && retries < MAX_RETRIES) {
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
                transaction.partialSign(keyPair);

                // 트랜잭션 전송
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

                success = true;
                return { success: true, message: `성공적으로 미스터리 박스를 열었습니다, ${openData.data.reward}!` };
            }
        } catch (e) {
            console.error('미스터리 박스 개봉 오류:', e.message);
            retries++;
            await new Promise(resolve => setTimeout(resolve, 5000)); // 5초 대기 후 재시도
        }
    }

    return { success: false, message: '최대 재시도 횟수를 초과했습니다. 다음 단계로 넘어갑니다.' };
};
