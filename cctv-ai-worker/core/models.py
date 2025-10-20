# core/models.py
import torch
import torch.nn as nn

class YoloLSTM(nn.Module):
    """
    Simple LSTM-based anomaly detection model (YOLO-free).
    Assumes pre-extracted spatial features or direct frame embeddings as input.
    Input shape: (batch, seq_len, 64, 64, 3)
    """

    def __init__(self, input_size=64*64*3, hidden_size=256, num_layers=2, num_classes=2, dropout=0.3):
        super(YoloLSTM, self).__init__()
        self.input_size = input_size
        self.hidden_size = hidden_size

        self.flatten = nn.Flatten(start_dim=2)
        self.lstm = nn.LSTM(
            input_size=input_size,
            hidden_size=hidden_size,
            num_layers=num_layers,
            batch_first=True,
            dropout=dropout
        )
        self.fc = nn.Linear(hidden_size, num_classes)
        self.softmax = nn.Softmax(dim=1)

    def forward(self, x):
        # x shape: (batch, seq_len, H, W, C)
        B, T, H, W, C = x.shape
        x = x.view(B, T, -1)             # (B, T, H*W*C)
        lstm_out, _ = self.lstm(x)       # (B, T, hidden)
        last_out = lstm_out[:, -1, :]    # use last timestep
        logits = self.fc(last_out)       # (B, num_classes)
        probs = self.softmax(logits)
        return probs


def load_model(model_path: str, device: str = "cpu") -> YoloLSTM:
    model = YoloLSTM()
    checkpoint = torch.load(model_path, map_location=device)
    if isinstance(checkpoint, dict) and "state_dict" in checkpoint:
        model.load_state_dict(checkpoint["state_dict"])
    else:
        model.load_state_dict(checkpoint)
    model.eval()
    return model.to(device)
